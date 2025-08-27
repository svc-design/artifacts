#!/usr/bin/env bash
# gitops/scripts/ingress-installer.sh
set -euo pipefail

# ======================
# Config & Defaults
# ======================
: "${NGINX_IC_IMAGE:=nginx/nginx-ingress:2.4.0}"
: "${CERT_IMG:=registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407}"

# 这些是我们在构建离线 OCI 归档时写入的“内部引用名”（ref.name）
# 若你的打包工作流改了它们，这里也要相应修改
: "${OCI_NGINX_REF:=nginx-ingress-2.4.0}"
: "${OCI_CERT_REF:=kube-webhook-certgen}"

: "${CHART_DIR:=./charts/nginx-ingress}"
: "${NAMESPACE:=ingress}"
: "${OCI_ARCHIVE:=images/oci-archive.tar}"
: "${NERDCTL_TAR:=nerdctl.tar.gz}"

# 1st arg: Ingress 对外 IP（默认取本机第一个 IP）
INGRESS_IP="${1:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
# 2nd arg: 节点标签（形如 "node-role=ingress"）
NODE_LABEL="${2:-}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

log()  { echo -e "$@"; }
die()  { echo "❌ $*" >&2; exit 1; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

have_cmd() { command -v "$1" &>/dev/null; }

# ======================
# Nerdctl Install (wrapper+多平台)
# ======================
install_nerdctl() {
  if [ -f "${NERDCTL_TAR}" ]; then
    log "📦 安装 nerdctl（多平台 + wrapper）..."
    $SUDO tar xzf "${NERDCTL_TAR}" -C /usr/local/bin/
    $SUDO chmod +x /usr/local/bin/nerdctl || true
  else
    warn "未找到 ${NERDCTL_TAR}，跳过解包（确保系统已有 nerdctl/ctr）。"
  fi
}

# ======================
# Import OCI images
# ======================
import_images_from_oci() {
  [ -f "${OCI_ARCHIVE}" ] || die "未找到 OCI 归档: ${OCI_ARCHIVE}"

  log "📦 准备从 OCI 归档导入镜像: ${OCI_ARCHIVE}"

  # 情况 A：Docker 环境
  if have_cmd docker && docker info &>/dev/null; then
    log "🔎 检测到 Docker 运行中。"
    if ! have_cmd skopeo; then
      die "检测到 Docker，但未安装 skopeo。Docker 无法直接导入 OCI Layout，请安装 skopeo 或在 containerd 环境执行。"
    fi
    log "🔁 使用 skopeo 将归档中的两个镜像导入 docker-daemon ..."
    # 必须显式指定 oci-archive 内部的 ref.name
    skopeo --insecure-policy copy --all "oci-archive:${OCI_ARCHIVE}:${OCI_NGINX_REF}" "docker-daemon:${NGINX_IC_IMAGE}"
    skopeo --insecure-policy copy --all "oci-archive:${OCI_ARCHIVE}:${OCI_CERT_REF}"  "docker-daemon:${CERT_IMG}"
    ok "已导入到 Docker 本地镜像：${NGINX_IC_IMAGE}, ${CERT_IMG}"
    return
  fi

  # 情况 B：K3s 的 containerd
  if [ -S /run/k3s/containerd/containerd.sock ]; then
    log "🔎 检测到 K3s containerd，使用 ctr 导入（含多架构）..."
    $SUDO ctr -n k8s.io images import --all-platforms "${OCI_ARCHIVE}"
    # retag 成 chart 会使用的镜像名
    $SUDO ctr -n k8s.io images tag "${OCI_NGINX_REF}" "${NGINX_IC_IMAGE}" || true
    $SUDO ctr -n k8s.io images tag "${OCI_CERT_REF}"  "${CERT_IMG}"       || true
    ok "已导入并完成 tag：${NGINX_IC_IMAGE}, ${CERT_IMG}"
    return
  fi

  # 情况 C：通用 containerd
  if [ -S /run/containerd/containerd.sock ]; then
    log "🔎 检测到系统 containerd，使用 ctr 导入（含多架构）..."
    $SUDO ctr -n k8s.io images import --all-platforms "${OCI_ARCHIVE}"
    $SUDO ctr -n k8s.io images tag "${OCI_NGINX_REF}" "${NGINX_IC_IMAGE}" || true
    $SUDO ctr -n k8s.io images tag "${OCI_CERT_REF}"  "${CERT_IMG}"       || true
    ok "已导入并完成 tag：${NGINX_IC_IMAGE}, ${CERT_IMG}"
    return
  fi

  die "未检测到可用的容器运行时（docker 或 containerd）。"
}

# ======================
# Kubernetes & Helm
# ======================
ensure_namespace() {
  log "📁 创建命名空间 ${NAMESPACE}（如已存在忽略）"
  kubectl create namespace "${NAMESPACE}" 2>/dev/null || true
}

generate_values() {
  log "🧾 生成 Helm values.yaml"
  cat > values.yaml <<EOF
controller:
  ingressClass: nginx
  ingressClassResource:
    enabled: true
  replicaCount: 2
  image:
    registry: docker.io
    image: nginx/nginx-ingress
    tag: "2.4.0"
  service:
    enabled: true
    type: NodePort
    externalIPs:
      - ${INGRESS_IP}
    nodePorts:
      http: 80
      https: 443
EOF

  if [[ -n "${NODE_LABEL}" ]]; then
    cat >> values.yaml <<EOF
  nodeSelector:
    ${NODE_LABEL%%=*}: "${NODE_LABEL#*=}"
EOF
  fi
}

install_chart() {
  [ -d "${CHART_DIR}" ] || die "未找到 Chart 目录：${CHART_DIR}"
  log "🧭 使用本地 Chart 安装/升级 NGINX Ingress：${CHART_DIR}"
  helm upgrade --install nginx "${CHART_DIR}" \
    --namespace "${NAMESPACE}" -f values.yaml
}

apply_configmap_tuning() {
  log "🛠️  应用 ConfigMap 优化参数"
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-nginx-ingress
  namespace: ${NAMESPACE}
data:
  proxy-connect-timeout: "10"
  proxy-read-timeout: "10"
  client-header-buffer-size: 64k
  client-body-buffer-size: 64k
  client-max-body-size: 1000m
  proxy-buffers: "8 32k"
  proxy-buffer-size: 32k
EOF
}

# ======================
# Main
# ======================
log "🚀 Ingress 离线部署开始"
log "   Ingress IP: ${INGRESS_IP:-<auto>}"
log "   Namespace:  ${NAMESPACE}"
log "   Chart Dir:  ${CHART_DIR}"
log "   Images:     ${NGINX_IC_IMAGE} , ${CERT_IMG}"

install_nerdctl
import_images_from_oci
ensure_namespace
generate_values
install_chart
apply_configmap_tuning
ok "离线安装完成，Ingress IP: ${INGRESS_IP}"
