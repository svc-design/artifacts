#!/usr/bin/env bash
set -euo pipefail

########################################
# Config (可用环境变量覆盖)
########################################
# 优先使用显式传入的 MASTER_IP，其次尝试 NodeIP，再自动探测本机 IP
MASTER_IP="${MASTER_IP:-${NodeIP:-$(hostname -I | awk '{print $1}')}}"
MASTER_USER="${MASTER_USER:-root}"
MASTER_SSH_KEY="${MASTER_SSH_KEY:-/root/.ssh/id_rsa}"

K8S_VERSION="${K8S_VERSION:-v1.29.9}"      # 也可改成 v1.30.x
HELM_APP_VERSION="${HELM_APP_VERSION:-v3.16.2}"
CILIUM_CHART_VERSION="${CILIUM_CHART_VERSION:-1.18.1}"
CILIUM_VALUES_FILE="${CILIUM_VALUES_FILE:-cilium-values.yaml}"

IMAGES_TAR="${IMAGES_TAR:-images/sealos-images.tar}"

########################################
# 可选：安装 sealos 二进制（离线包）
########################################
# 自动探测架构并解压对应的 sealos 离线包
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    ARCH=amd64
    ;;
  aarch64|arm64)
    ARCH=arm64
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

SEALOS_TARBALL="${SEALOS_TARBALL:-sealos_${SEALOS_VERSION:-5.0.1}_linux_${ARCH}.tar.gz}"
if [[ -f "$SEALOS_TARBALL" ]]; then
  tar -xpvf "$SEALOS_TARBALL"
  install -m 0755 sealos /usr/local/bin/sealos
  install -m 0755 sealctl /usr/local/bin/ || true
  install -m 0755 image-cri-shim /usr/local/bin/ || true
  [[ -f nerdctl ]] && install -m 0755 nerdctl /usr/local/bin/ || true
fi

########################################
# 预加载镜像（可选）
########################################
if [[ -f "$IMAGES_TAR" ]]; then
  if command -v sealos >/dev/null 2>&1; then
    sealos load -i "$IMAGES_TAR" || true
  elif command -v docker >/dev/null 2>&1; then
    docker load -i "$IMAGES_TAR" || true
  fi
fi

########################################
# 用 sealos 起集群（跳过 kube-proxy）
# 注意：不再引入 labring/cilium，避免版本混装
########################################
sealos run "labring/kubernetes:${K8S_VERSION}" \
           "labring/helm:${HELM_APP_VERSION}" \
           --masters "${MASTER_IP}" \
           --user "${MASTER_USER}" \
           --pk "${MASTER_SSH_KEY}" \
           --env '{}' \
           --cmd 'kubeadm init --skip-phases=addon/kube-proxy'

########################################
# 安装 / 升级 Cilium（Helm 统一到 1.18.x）
########################################
helm repo add cilium https://helm.cilium.io || true
helm repo update
helm upgrade --install cilium cilium/cilium \
  -n kube-system \
  --version "${CILIUM_CHART_VERSION}" \
  -f "${CILIUM_VALUES_FILE}"

# 等待就绪（超时放宽以适配慢环境）
kubectl -n kube-system rollout status ds/cilium --timeout=10m || true
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=5m || true

# 快速查看
cilium status || true
kubectl -n kube-system get pods -o wide
helm list -n kube-system
