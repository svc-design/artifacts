#!/bin/bash
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-labring/kubernetes:v1.29.9}"
CILIUM_VERSION="${CILIUM_VERSION:-labring/cilium:v1.13.4}"
HELM_VERSION="${HELM_VERSION:-labring/helm:v3.9.4}"

ARCH="${ARCH:-amd64}"
IMAGES=("$K8S_VERSION" "$CILIUM_VERSION" "$HELM_VERSION")
WORKDIR="sealos-offline-package"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/images"

for img in "${IMAGES[@]}"; do
  docker pull --platform "linux/${ARCH}" "$img"
done

docker save "${IMAGES[@]}" -o "$WORKDIR/images/sealos-images.tar"

cp "$SCRIPT_DIR/cilium-values.yaml" "$WORKDIR/"
cp "$SCRIPT_DIR/sealos-install.sh" "$WORKDIR/"
chmod +x "$WORKDIR/sealos-install.sh"

tar czf "sealos-offline-package-${ARCH}.tar.gz" "$WORKDIR"

echo "Created sealos-offline-package-${ARCH}.tar.gz"
