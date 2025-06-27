#!/bin/bash
set -euo pipefail

# === 全局变量 ===
MASTER_IP=$(hostname -I | awk '{print $1}')
USER=${USER:-$(whoami)}
SSH_KEY="${HOME}/.ssh/id_rsa"
K8S_VERSION="labring/kubernetes:v1.25.16"
CILIUM_VERSION="labring/cilium:v1.13.4"
HELM_VERSION="labring/helm:v3.9.4"
NVIDIA_DRIVER_VERSION="nvidia-driver-535"
NVIDIA_PLUGIN_VERSION="v0.17.1"
NERDCTL_VERSION="2.1.2"
PROXY_ADDR="http://127.0.0.1:1081"
USE_PROXY=${USE_PROXY:-false}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE_DIR=${OFFLINE_DIR:-$SCRIPT_DIR}

# 部署模式: kubeadm 或 sealos
# 默认使用 kubeadm，可通过环境变量 DEPLOY_MODE 覆盖
DEPLOY_MODE=${DEPLOY_MODE:-kubeadm}

# 加载镜像的工具: sealos、nerdctl 或 docker
# 默认使用 sealos，可通过 IMAGE_LOAD_TOOL 环境变量覆盖
IMAGE_LOAD_TOOL=${IMAGE_LOAD_TOOL:-sealos}

# === 选项代理 ===
configure_proxy() {
  if [ "$USE_PROXY" = true ]; then
    export http_proxy=$PROXY_ADDR
    export https_proxy=$PROXY_ADDR
    export HTTP_PROXY=$PROXY_ADDR
    export HTTPS_PROXY=$PROXY_ADDR
    echo "🌐 代理已启用: $PROXY_ADDR"
  else
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    echo "🌐 代理已关闭"
  fi
}

proxy_curl() {
  if [ "$USE_PROXY" = true ]; then
    curl --proxy "$PROXY_ADDR" "$@"
  else
    curl "$@"
  fi
}

load_offline_images() {
  local tar="${OFFLINE_DIR}/images/gpu_k8s_images.tar"
  [ -f "$tar" ] || return 0
  echo "📦 导入离线镜像..."
  case "$IMAGE_LOAD_TOOL" in
    sealos)
      if command -v sealos &>/dev/null; then
        sealos load -i "$tar"
        return
      fi
      ;;
    nerdctl)
      if command -v nerdctl &>/dev/null; then
        sudo nerdctl load -i "$tar"
        return
      fi
      ;;
    docker)
      if command -v docker &>/dev/null; then
        docker load -i "$tar"
        return
      fi
      ;;
    *)
      echo "❌ 不支持的加载工具: $IMAGE_LOAD_TOOL"
      return 1
      ;;
  esac

  echo "❌ 无法找到 $IMAGE_LOAD_TOOL 用于加载镜像"
  return 1
}

install_all_offline_packages() {
  if [ -d "${OFFLINE_DIR}/packages" ]; then
    echo "📦 Using offline deb packages"
    sudo dpkg -i ${OFFLINE_DIR}/packages/*.deb 2>/dev/null || sudo apt-get -f install -y
    return 0
  fi
  return 1
}

install_base() {
  echo "[1/8] 安装基础依赖"
  install_all_offline_packages || {
    sudo apt-get update -y
    sudo apt-get install -y curl gnupg2 ca-certificates lsb-release \
      apt-transport-https software-properties-common openssh-client \
      openssh-server uidmap containerd ${NVIDIA_DRIVER_VERSION} nvidia-container-toolkit
  }
}

install_containerd() {
  echo "[2/8] 安装 containerd + nerdctl"
  sudo apt-get purge -y docker.io docker-ce docker-ce-cli containerd.io || true
  if ! install_all_offline_packages; then
    sudo apt-get install -y containerd
  fi

  archive="nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"
  if [ -f "${OFFLINE_DIR}/${archive}" ]; then
    tmpdir="$OFFLINE_DIR"
  else
    tmpdir=$(mktemp -d)
    url="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/${archive}"
    echo "🔽 下载 nerdctl: $url"
    proxy_curl -fLo "${tmpdir}/${archive}" "$url"
  fi

  echo "📅 解压 nerdctl 到 /usr/local"
  sudo tar -xzf "${tmpdir}/${archive}" -C /usr/local

  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
  sudo systemctl enable --now containerd
  nerdctl --version && echo "✅ nerdctl 安装成功" || echo "❌ nerdctl 安装失败"
}

install_nvidia() {
  echo "[3/8] 安装 NVIDIA 驱动和容器工具"
  distribution="ubuntu22.04"
  if [ -f "${OFFLINE_DIR}/nvidia-gpgkey" ]; then
    sudo install -m 0644 "${OFFLINE_DIR}/nvidia-gpgkey" /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  else
    proxy_curl -sL https://nvidia.github.io/nvidia-docker/gpgkey | \
      sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  fi

  if ! install_all_offline_packages; then
    proxy_curl -sL https://nvidia.github.io/nvidia-docker/${distribution}/nvidia-docker.list | \
      sed 's|^deb |deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] |' | \
      sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    sudo apt-get update -y
    sudo apt-get install -y ${NVIDIA_DRIVER_VERSION} nvidia-container-toolkit
  fi
  if [ "$DEPLOY_MODE" = "sealos" ]; then
    sudo nvidia-ctk runtime configure \
      --config /var/lib/sealos/data/default/rootfs/etc/containerd/config.toml \
      --set-as-default
    sudo systemctl restart sealos-containerd
  else
    sudo nvidia-ctk runtime configure --runtime=containerd --set-as-default
    sudo systemctl restart containerd
  fi
  if ! command -v nvidia-smi >/dev/null; then echo "❌ nvidia-smi 未找到"; exit 1; fi
  nvidia-smi || { echo "❌ NVIDIA 驱动有问题"; exit 1; }
}

install_sealos() {
  echo "[4/8] 安装 Sealos"
  if command -v sealos &>/dev/null; then
    return
  fi
  if [ -f "${OFFLINE_DIR}/sealos_5.0.1_linux_amd64.deb" ]; then
    sudo dpkg -i "${OFFLINE_DIR}/sealos_5.0.1_linux_amd64.deb"
  else
    proxy_curl -sfL https://raw.githubusercontent.com/labring/sealos/main/scripts/install.sh | bash
  fi
}

install_kubeadm() {
  echo "📦 安装 kubeadm、kubelet、kubectl"

  # 默认安装版本，可传参覆盖
  local KUBE_VERSION="${1:-1.25.16}"

  echo "➡️ 目标版本: $KUBE_VERSION"

  if [ -d "${OFFLINE_DIR}/packages" ] && ls "${OFFLINE_DIR}/packages"/kubeadm_* &>/dev/null; then
    echo "📦 使用离线 deb 安装 kubeadm/kubelet/kubectl"
    sudo dpkg -i "${OFFLINE_DIR}/packages"/kube{adm,let,ctl}_*${KUBE_VERSION}-00*.deb 2>/dev/null || \
      sudo apt-get -f install -y
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable --now kubelet
    echo "✅ kubeadm/kubelet/kubectl 离线安装完成（版本 ${KUBE_VERSION}）"
    return
  fi

  # 在线安装
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

  sudo mkdir -p /etc/apt/keyrings
  if [ -f "${OFFLINE_DIR}/kubernetes-archive-keyring.gpg" ]; then
    sudo cp "${OFFLINE_DIR}/kubernetes-archive-keyring.gpg" /etc/apt/keyrings/
  else
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
      gpg --dearmor | sudo tee /etc/apt/keyrings/kubernetes-archive-keyring.gpg > /dev/null
  fi

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] \
    https://apt.kubernetes.io/ kubernetes-xenial main" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

  sudo apt-get update

  # 安装指定版本的 kubeadm/kubelet/kubectl
  sudo apt-get install -y \
    kubelet=${KUBE_VERSION}-00 \
    kubeadm=${KUBE_VERSION}-00 \
    kubectl=${KUBE_VERSION}-00

  sudo apt-mark hold kubelet kubeadm kubectl

  echo "✅ kubeadm/kubelet/kubectl 安装完成（版本 ${KUBE_VERSION}）"

  # 启动 kubelet（kubeadm init 后才会真正激活）
  sudo systemctl enable --now kubelet
}

setup_ssh() {
  echo "[5/8] 配置 SSH 免密"
  [ ! -f "${SSH_KEY}" ] && ssh-keygen -f "${SSH_KEY}" -N ""
  cat "${SSH_KEY}.pub" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh
  sudo systemctl enable --now ssh || sudo systemctl enable --now sshd
}

# === 修改的 deploy_k8s 支持 sealos / kubeadm 两种模式 ===
deploy_k8s() {
  echo "[6/8] 部署 Kubernetes，模式: $DEPLOY_MODE"
  MASTER_IP=$(hostname -I | awk '{print $1}')

  if [ "$DEPLOY_MODE" = "sealos" ]; then
    echo "[6.0] 使用 Sealos 部署 Kubernetes"
    load_offline_images || true
    sealos run "$K8S_VERSION" "$CILIUM_VERSION" "$HELM_VERSION" \
      --masters "$MASTER_IP" --user "$USER" --pk "$SSH_KEY" \
      --env '{}' --cmd "kubeadm init --skip-phases=addon/kube-proxy"
  else
    echo "[6.0] 使用 kubeadm 初始化 K8s master 节点"
    sudo kubeadm init \
      --pod-network-cidr=10.42.0.0/16 \
      --apiserver-advertise-address="$MASTER_IP" \
      --skip-phases=addon/kube-proxy

    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown "$(id -u):$(id -g)" $HOME/.kube/config

    echo "[6.1] 安装 Cilium 网络插件（无 kube-proxy 模式）"
    helm repo add cilium https://helm.cilium.io/ || true
    helm repo update
    helm install cilium cilium/cilium --version "${CILIUM_VERSION:-1.13.4}" \
      --namespace kube-system \
      --set kubeProxyReplacement=true \
      --set k8sServiceHost="$MASTER_IP" \
      --set k8sServicePort=6443
  fi

  echo "[6.2] Kubernetes 部署完成 ✅"
}

deploy_plugin() {
  echo "[7/8] 部署 NVIDIA Device Plugin"
  local plugin_file="${OFFLINE_DIR}/nvidia-device-plugin.yml"
  if [ -f "$plugin_file" ]; then
    kubectl apply -f "$plugin_file"
  else
    plugin_url="https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/${NVIDIA_PLUGIN_VERSION}/deployments/static/nvidia-device-plugin.yml"
    if [ "$USE_PROXY" = true ]; then
      HTTPS_PROXY=$PROXY_ADDR HTTP_PROXY=$PROXY_ADDR \
      kubectl apply -f "$plugin_url"
    else
      kubectl apply -f "$plugin_url"
    fi
  fi
  sleep 15
  kubectl -n kube-system get pods | grep nvidia || echo "⚠️ 插件未启动"
  kubectl describe node | grep -A10 Capacity | grep -i nvidia
}

run_test() {
  echo "[8/8] 运行 CUDA vectoradd GPU 测试"
  kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  restartPolicy: Never
  containers:
  - name: cuda-test
    image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0
    resources:
      limits:
        nvidia.com/gpu: 1
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
YAML
  kubectl wait pod/gpu-pod --for=condition=Succeeded --timeout=120s || true
  kubectl logs gpu-pod || echo "⚠️ 未获取日志"
}

show_help() {
  echo -e "用法: ./gpu-k8s.sh [阶段参数...]\n"
  echo "可用阶段:"
  echo "  --install-base         安装基础依赖"
  echo "  --install-containerd   安装 containerd + nerdctl"
  echo "  --install-nvidia       安装 NVIDIA 驱动和工具"
  echo "  --install-sealos       安装 Sealos"
  echo "  --install-kubeadm      安装 kubeadm/kubelet/kubectl"
  echo "  --setup-ssh            配置 SSH 免密"
  echo "  --load_offline_images  导入离线镜像"
  echo "  --deploy-k8s           部署 Kubernetes（支持 sealos/kubeadm）"
  echo "  --deploy-plugin        部署 NVIDIA Device Plugin"
  echo "  --run-test             运行 GPU 测试"
  echo "  --all                  全部步骤执行"
  echo ""
  echo "环境变量:"
  echo "  OFFLINE_DIR           指定离线包解压目录，默认为脚本所在目录"
  echo "  DEPLOY_MODE           设置部署模式（kubeadm 或 sealos，默认 kubeadm）"
  echo "  IMAGE_LOAD_TOOL       选择加载镜像的工具（sealos|nerdctl|docker，默认 sealos）"
  echo -e "\n示例命令\t\t\t说明"
  echo "USE_PROXY=true ./gpu-k8s.sh --install-nvidia      # 只安装 NVIDIA 工具包并走代理"
  echo "DEPLOY_MODE=sealos ./gpu-k8s.sh --deploy-k8s       # 使用 sealos 部署 K8s"
  echo "USE_PROXY=false ./gpu-k8s.sh --all                # 全流程执行但不使用代理"
  echo "OFFLINE_DIR=/path/to/offline DEPLOY_MODE=sealos ./gpu-k8s.sh --all   # 使用离线包运行"
  echo "IMAGE_LOAD_TOOL=nerdctl ./gpu-k8s.sh --load_offline_images            # 选择 nerdctl 导入镜像"
}

# === 执行 ===
configure_proxy

if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --install-base) install_base ;;
    --install-containerd) install_containerd ;;
    --install-nvidia) install_nvidia ;;
    --install-sealos) install_sealos ;;
    --install-kubeadm) install_kubeadm ;;
    --setup-ssh) setup_ssh ;;
    --load_offline_images) load_offline_images ;;
    --deploy-k8s) deploy_k8s ;;
    --deploy-plugin) deploy_plugin ;;
    --run-test) run_test ;;
    --all)
      install_base
      install_containerd
      install_nvidia
      install_sealos
      if [ "$DEPLOY_MODE" = "kubeadm" ]; then
        install_kubeadm
      fi
      setup_ssh
      deploy_k8s
      deploy_plugin
      run_test
      ;;
    *) show_help; exit 1 ;;
  esac
  echo
done
