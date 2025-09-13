#!/usr/bin/env bash
# gitops/scripts/ingress-installer.sh
# 目标：最小化参数/分支，专注“一键离线安装”
set -euo pipefail

# ======================
# Config & Defaults（仅支持环境变量覆盖）
# ======================
: "${NGINX_IC_IMAGE:=nginx/nginx-ingress:2.4.0}"
: "${CERT_IMG:=registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407}"

# 打包阶段写入的 OCI layout 内部引用名（如果你改了打包 ref.name，这里相应改）
: "${OCI_NGINX_REF:=nginx-ingress-2.4.0}"
: "${OCI_CERT_REF:=kube-webhook-certgen}"

# 目录布局固定：charts、images、脚本位于离线包根目录
: "${CHART_DIR:=./charts/nginx-ingress}"
: "${NAMESPACE:=ingress}"
: "${OCI_ARCHIVE:=images/oci-archive.tar}"         # 优先使用
: "${DOCKER_IMG_TAR:=images/nginx-ingress.tar}"    # 回退（docker save）
: "${DOCKER_CERT_TAR:=images/kube-webhook-certgen.tar}"
: "${NERDCTL_TAR:=nerdctl.tar.gz}"

# Ingress 暴露 IP（默认取本机第一块网卡 IP），节点选择器可选（key=value）
INGRESS_IP="${INGRESS_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
NODE_LABEL="${NODE_LABEL:-}"

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

log()  { echo -e "$@"; }
die()  { echo "❌ $*" >&2; exit 1; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
have() { command -v "$1" &>/dev/null; }

# ======================
# Nerdctl Install (wrapper)
# ======================
install_nerdctl() {
  if [ -f "${NERDCTL_TAR}" ]; then
    log "📦 安装 nerdctl（wrapper）..."
    $SUDO tar xzf "${NERDCTL_TAR}" -C /usr/local/bin/
    $SUDO chmod +x /usr/local/bin/nerdctl || true
  fi
}

# ======================
# Import images（优先 OCI，其次 docker save tar）
# ======================
import_images_from_oci() {
  # 首选：OCI 归档
  if [ -f "${OCI_ARCHIVE}" ]; then
    log "📦 从 OCI 归档导入镜像：${OCI_ARCHIVE}"
    # A) Docker 环境（需要 skopeo）
    if have docker && docker info &>/dev/null; then
      if have skopeo; then
        skopeo --insecure-policy copy --all "oci-archive:${OCI_ARCHIVE}:${OCI_NGINX_REF}" "docker-daemon:${NGINX_IC_IMAGE}"
        skopeo --insecure-policy copy --all "oci-archive:${OCI_ARCHIVE}:${OCI_CERT_REF}"  "docker-daemon:${CERT_IMG}"
        ok "OCI → docker-daemon 导入完成"
        return
      else
        warn "docker 环境未安装 skopeo，改用 docker-archive 回退（需 images/*.tar）"
      fi
    fi
    # B) containerd 环境（K3s 或系统 containerd）
    if [ -S /run/k3s/containerd/containerd.sock ] || [ -S /run/containerd/containerd.sock ]; then
      local ns="k8s.io"
      $SUDO ctr -n "${ns}" images import --all-platforms "${OCI_ARCHIVE}"
      $SUDO ctr -n "${ns}" images tag "${OCI_NGINX_REF}" "${NGINX_IC_IMAGE}" || true
      $SUDO ctr -n "${ns}" images tag "${OCI_CERT_REF}"  "${CERT_IMG}"       || true
      ok "OCI → containerd 导入完成"
      return
    fi
    warn "未检测到 docker/skopo 或 containerd 可直接用 OCI 导入，尝试 docker-archive 回退。"
  fi

  # 回退：docker save 的 tar 包
  if [ -f "${DOCKER_IMG_TAR}" ] && [ -f "${DOCKER_CERT_TAR}" ]; then
    log "📦 从 docker-archive tar 回退导入 images/*.tar"
    if have docker && docker info &>/dev/null; then
      docker load -i "${DOCKER_IMG_TAR}"
      docker load -i "${DOCKER_CERT_TAR}"
      ok "docker load 完成"
      return
    fi
    if have nerdctl; then
      nerdctl load -i "${DOCKER_IMG_TAR}"
      nerdctl load -i "${DOCKER_CERT_TAR}"
      ok "nerdctl load 完成"
      return
    fi
    if [ -S /run/k3s/containerd/containerd.sock ] || [ -S /run/containerd/containerd.sock ]; then
      $SUDO ctr -n k8s.io images import --all-platforms "${DOCKER_IMG_TAR}"
      $SUDO ctr -n k8s.io images import --all-platforms "${DOCKER_CERT_TAR}"
      ok "ctr import 完成"
      return
    fi
    die "找不到可用容器运行时导入 images/*.tar"
  fi

  die "未发现可用的镜像来源（缺少 ${OCI_ARCHIVE} 或 ${DOCKER_IMG_TAR}/${DOCKER_CERT_TAR)})"
}

# ======================
# Kubernetes & Helm
# ======================
ensure_namespace() {
  log "📁 创建命名空间 ${NAMESPACE}（如已存在忽略）"
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
}

generate_values() {
  log "🧾 生成 Helm values.yaml"
  local repo tag
  repo="${NGINX_IC_IMAGE%:*}"
  tag="${NGINX_IC_IMAGE##*:}"

  cat > values.yaml <<EOF
controller:
  ingressClass: nginx
  ingressClassResource:
    enabled: true
  replicaCount: 2
  image:
    repository: ${repo}
    tag: "${tag}"
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
  log "🧭 使用本地 Chart 安装/升级：${CHART_DIR}"
  helm upgrade --install nginx "${CHART_DIR}" \
    --namespace "${NAMESPACE}" -f values.yaml \
    --wait --timeout 10m
}

apply_configmap_tuning() {
  log "🛠️  应用 ConfigMap 调优参数"
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
