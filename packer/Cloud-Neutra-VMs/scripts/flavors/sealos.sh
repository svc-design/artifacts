#!/usr/bin/env bash
set -euo pipefail

echo "[Cloud-Neutra] Installing Sealos"

ARCH="$(uname -m)"
VERSION="5.0.0-alpha1"

if [[ "$ARCH" == "x86_64" ]]; then
  URL="https://github.com/labring/sealos/releases/download/v${VERSION}/sealos_${VERSION}_linux_amd64.tar.gz"
else
  URL="https://github.com/labring/sealos/releases/download/v${VERSION}/sealos_${VERSION}_linux_arm64.tar.gz"
fi

curl -LO $URL
tar -xzf sealos_*.tar.gz
sudo mv sealos /usr/local/bin/
rm -f sealos_*.tar.gz

echo "[Cloud-Neutra] Sealos installed."
