#!/usr/bin/env bash
# scripts/ingress-installer.sh
# 目标：一键“离线安装” NGINX Ingress，兼容 K3s 1.29~1.33（containerd）
set -euo pipefail

# ======================
# Config & Defaults（仅支持环境变量覆盖）
# ======================
: "${NGINX_IC_IMAGE:=nginx/nginx-ingress:5.1.1}"
: "${CERT_IMG:=registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407}"

# 打包阶段写入的 OCI layout 内部引用名（如果你改了打包 ref.name，这里相应改）
: "${OCI_NGINX_REF:=nginx-ingress-5.1.1}"
: "${OCI_CERT_REF:=kube-webhook-certgen}"

# 目录布局固定：charts、images、脚本位于离线包根目录
: "${CHART_DIR:=./charts/nginx-ingress}"
: "${NAMESPACE:=ingress}"
: "${OCI_ARCHIVE:=images/oci-archive.tar}"         # 优先使用（oci-archive）
: "${DOCKER_IMG_TAR:=images/nginx-ingress.tar}"    # 回退（docker-archive）
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
# Runtime Detection（K3s / containerd / docker / nerdctl）
# ======================
NERDCTL_BIN=""
detect_nerdctl() {
  # 优先使用离线包内置路径（install_nerdctl 会解到 /usr/local/bin/nerdctl）
  if [ -x /usr/local/bin/nerdctl ]; then
    NERDCTL_BIN="/usr/local/bin/nerdctl"
  elif have nerdctl; then
    NERDCTL_BIN="$(command -v nerdctl)"
  else
    NERDCTL_BIN=""
  fi
}
have_nerdctl() { [ -n "${NERDCTL_BIN}" ]; }

detect_containerd() {
  # 优先使用 K3s 的 containerd
  if [ -S /run/k3s/containerd/containerd.sock ]; then
    CTR_SOCK="/run/k3s/containerd/containerd.sock"
    CTR_NS="k8s.io"
    if have k3s; then
      CTR_BIN="k3s ctr"  # 避免系统 ctr 指向其他 containerd
    else
      CTR_BIN="ctr --address ${CTR_SOCK}"
    fi
    NERDCTL_ADDR_OPT=(--address "${CTR_SOCK}" --namespace "${CTR_NS}")
    return
  fi

  # 其次使用系统 containerd
  if [ -S /run/containerd/containerd.sock ]; then
    CTR_SOCK="/run/containerd/containerd.sock"
    CTR_NS="k8s.io"
    CTR_BIN="ctr --address ${CTR_SOCK}"
    NERDCTL_ADDR_OPT=(--address "${CTR_SOCK}" --namespace "${CTR_NS}")
    return
  fi

  CTR_SOCK=""
}

# 统一的 ctr/nerdctl 执行器
ctr_exec() {
  # shellcheck disable=SC2086
  ${CTR_BIN} -n "${CTR_NS}" "$@"
}
nerdctl_exec() {
  "${NERDCTL_BIN}" "${NERDCTL_ADDR_OPT[@]}" "$@"
}

# ======================
# Nerdctl Install (wrapper)
# ======================
install_nerdctl() {
  if [ -f "${NERDCTL_TAR}" ]; then
    log "📦 安装 nerdctl（wrapper）..."
    $SUDO tar xzf "${NERDCTL_TAR}" -C /usr/local/bin/
    $SUDO chmod +x /usr/local/bin/nerdctl || true
  fi
  detect_nerdctl
  if have_nerdctl; then
    log "🧰 nerdctl 就绪：${NERDCTL_BIN}"
  else
    warn "未检测到 nerdctl，将仅依赖 ctr/docker 执行导入。"
  fi
}

# ======================
# Import images（优先 OCI，其次 docker-archive）
# ======================
import_images_from_oci() {
  detect_containerd
  log "🔌 containerd socket: ${CTR_SOCK:-<not found>}"

  # 首选：OCI 归档（oci-archive）—— 标准且最稳
  if [ -f "${OCI_ARCHIVE}" ]; then
    log "📦 从 OCI 归档导入镜像：${OCI_ARCHIVE}"

    # A) Docker 守护进程（需要 skopeo）—— 可选路径
    if have docker && docker info &>/dev/null; then
      if have skopeo; then
        skopeo --insecure-policy copy --all "oci-archive:${OCI_ARCHIVE}:${OCI_NGINX_REF}" "docker-daemon:${NGINX_IC_IMAGE}"
        skopeo --insecure-policy copy --all "oci-archive:${OCI_ARCHIVE}:${OCI_CERT_REF}"  "docker-daemon:${CERT_IMG}"
        ok "OCI → docker-daemon 导入完成"
        return
      else
        warn "docker 环境未安装 skopeo，改用 containerd 路径。"
      fi
    fi

    # B) containerd 环境（K3s 或系统 containerd）—— 主路径
    if [ -n "${CTR_SOCK}" ]; then
      ctr_exec images import --all-platforms "${OCI_ARCHIVE}"
      # 补打期望 tag（让 ctr/nerdctl/k8s 三方都一致）
      ctr_exec images tag "${OCI_NGINX_REF}" "${NGINX_IC_IMAGE}" || true
      ctr_exec images tag "${OCI_CERT_REF}"  "${CERT_IMG}"       || true

      # 若 nerdctl 可用，再用 nerdctl 做一次 tag（有助于命令行一致性）
      if have_nerdctl; then
        nerdctl_exec tag "${OCI_NGINX_REF}" "${NGINX_IC_IMAGE}" || true
        nerdctl_exec tag "${OCI_CERT_REF}"  "${CERT_IMG}"       || true
      fi

      ok "OCI → containerd 导入完成"
      return
    fi

    warn "未检测到可用于 OCI 导入的 containerd，将尝试 docker-archive 回退。"
  fi

  # 回退：docker save 的 tar 包（docker-archive）
  if [ -f "${DOCKER_IMG_TAR}" ] && [ -f "${DOCKER_CERT_TAR}" ]; then
    log "📦 从 docker-archive tar 回退导入 images/*.tar"

    # 优先：nerdctl（离线包自带/系统均可）
    if have_nerdctl; then
      if [ -n "${CTR_SOCK}" ]; then
        nerdctl_exec load -i "${DOCKER_IMG_TAR}"
        nerdctl_exec load -i "${DOCKER_CERT_TAR}"
      else
        # 极少见：未探测到 socket，尝试 nerdctl 默认
        "${NERDCTL_BIN}" load -i "${DOCKER_IMG_TAR}"
        "${NERDCTL_BIN}" load -i "${DOCKER_CERT_TAR}"
      fi
      ok "nerdctl load 完成"
      return
    fi

    # 其次：docker 守护进程
    if have docker && docker info &>/dev/null; then
      docker load -i "${DOCKER_IMG_TAR}"
      docker load -i "${DOCKER_CERT_TAR}"
      ok "docker load 完成"
      return
    fi

    # 兜底：ctr（可导入 docker-archive，但不如 nerdctl 稳妥）
    if [ -n "${CTR_SOCK}" ]; then
      ctr_exec images import --all-platforms "${DOCKER_IMG_TAR}"
      ctr_exec images import --all-platforms "${DOCKER_CERT_TAR}"
      ok "ctr import 完成"
      return
    fi

    die "找不到可用容器运行时导入 images/*.tar"
  fi

  die "未发现可用的镜像来源（缺少 ${OCI_ARCHIVE} 或 ${DOCKER_IMG_TAR}/${DOCKER_CERT_TAR}）"
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
  ingressClass:
    name: nginx
    create: true
    setAsDefaultIngress: false
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
