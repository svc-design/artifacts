#!/usr/bin/env bash
set -euo pipefail

echo "[Cloud-Neutra] Installing K3s (skip start)"

curl -sfL https://get.k3s.io -o install_k3s.sh
chmod +x install_k3s.sh

# Skip start (important for AMI)
sudo INSTALL_K3S_SKIP_START=true ./install_k3s.sh

sudo systemctl disable k3s || true

echo "[Cloud-Neutra] K3s installed (not started)."
