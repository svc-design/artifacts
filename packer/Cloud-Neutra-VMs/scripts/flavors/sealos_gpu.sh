#!/usr/bin/env bash
set -euo pipefail

echo "[Cloud-Neutra] Installing Sealos GPU edition"

##############################################
# Install NVIDIA drivers (AWS/AliCloud safe)
##############################################
if lspci | grep -i nvidia >/dev/null 2>&1; then
  echo "[GPU] NVIDIA GPU detected"
  sudo apt-get install -y nvidia-driver-535
else
  echo "[GPU] No NVIDIA GPU detected, skip driver"
fi

##############################################
# Install containerd (if not installed)
##############################################
sudo apt-get install -y containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl restart containerd

##############################################
# Install NVIDIA container toolkit
##############################################
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
  | sudo tee /etc/apt/sources.list.d/libnvidia-container.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd

##############################################
# Install Sealos
##############################################
ARCH="$(uname -m)"
VERSION="5.0.0-alpha1"

if [[ "$ARCH" == "x86_64" ]]; then
  URL="https://github.com/labring/sealos/releases/download/v${VERSION}/sealos_${VERSION}_linux_amd64.tar.gz"
else
  URL="https://github.com/labring/sealos/releases/download/v${VERSION}/sealos_${VERSION}_linux_arm64.tar.gz"
fi

curl -LO "$URL"
tar -xzf sealos_*.tar.gz
sudo mv sealos /usr/local/bin/
rm -f sealos_*.tar.gz

echo "[Cloud-Neutra] Sealos GPU edition installed."
