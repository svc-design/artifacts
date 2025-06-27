#!/bin/bash
set -euo pipefail

# Versions
K8S_VERSION="${K8S_VERSION:-labring/kubernetes:v1.29.9}"
CILIUM_VERSION="${CILIUM_VERSION:-labring/cilium:v1.13.4}"
HELM_VERSION="${HELM_VERSION:-labring/helm:v3.9.4}"
NERDCTL_VERSION="${NERDCTL_VERSION:-2.1.2}"
NVIDIA_PLUGIN_VERSION="${NVIDIA_PLUGIN_VERSION:-v0.17.1}"
NVIDIA_DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-nvidia-driver-535}"
CUDA_SAMPLE_IMAGE="${CUDA_SAMPLE_IMAGE:-nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0}"

IMAGES=(
  "$K8S_VERSION"
  "$CILIUM_VERSION"
  "$HELM_VERSION"
  "nvcr.io/nvidia/k8s-device-plugin:${NVIDIA_PLUGIN_VERSION}"
  "$CUDA_SAMPLE_IMAGE"
)

WORKDIR="offline"
mkdir -p "$WORKDIR/images" "$WORKDIR/packages"

# Download required APT packages
APT_PACKAGES=(
  curl gnupg2 ca-certificates lsb-release apt-transport-https \
  software-properties-common openssh-client openssh-server uidmap \
  containerd "$NVIDIA_DRIVER_VERSION" nvidia-container-toolkit
)

# Add NVIDIA repository for nvidia-container-toolkit
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L "https://nvidia.github.io/nvidia-docker/${distribution}/nvidia-docker.list" | \
  sed 's#^deb #deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] #' | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list


sudo apt-get update -y
sudo apt-get install --download-only -y "${APT_PACKAGES[@]}"
cp /var/cache/apt/archives/*.deb "$WORKDIR/packages/"
sudo apt-get clean

# Download sealos deb
curl -L -o "$WORKDIR/sealos_5.0.1_linux_amd64.deb" \
  https://github.com/labring/sealos/releases/download/v5.0.1/sealos_5.0.1_linux_amd64.deb

# Download nerdctl archive
nerdctl_archive="nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"
curl -L -o "$WORKDIR/${nerdctl_archive}" \
  "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/${nerdctl_archive}"

# Pull required container images
for img in "${IMAGES[@]}"; do
  echo "Pulling $img"
  docker pull "$img"
done

docker save -o "$WORKDIR/images/gpu_k8s_images.tar" "${IMAGES[@]}"

# Download NVIDIA device plugin manifest and gpg key
PLUGIN_FILE="nvidia-device-plugin.yml"
curl -L -o "$WORKDIR/${PLUGIN_FILE}" \
  "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/${NVIDIA_PLUGIN_VERSION}/deployments/static/${PLUGIN_FILE}"
curl -L -o "$WORKDIR/nvidia-gpgkey" https://nvidia.github.io/nvidia-docker/gpgkey

# Include deployment script
cp "$(dirname "$0")/gpu-k8s.sh" "$WORKDIR/"

# Create final archive
TAR_NAME="gpu_k8s_offline_packages.tar.gz"
tar -czf "$TAR_NAME" -C "$WORKDIR" .

echo "Created $TAR_NAME"
