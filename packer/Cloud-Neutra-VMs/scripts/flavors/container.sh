#!/usr/bin/env bash
set -euo pipefail

echo "[Cloud-Neutra] Installing containerd + nerdctl"

ARCH="$(uname -m)"
NERDCTL_VERSION="2.2.0"

##############################################
# Install containerd
##############################################
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl enable containerd
sudo systemctl restart containerd

##############################################
# Install nerdctl
##############################################
if [[ "$ARCH" == "x86_64" ]]; then
  URL="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz"
else
  URL="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-arm64.tar.gz"
fi

curl -LO $URL
tar -xzf nerdctl-*.tar.gz
sudo mv nerdctl /usr/local/bin/nerdctl
rm -f nerdctl-*.tar.gz

echo "[Cloud-Neutra] container edition installed."
