#!/bin/bash
set -euo pipefail

# Install sealos binaries
if [ -f "sealos_5.0.1_linux_amd64.tar.gz" ]; then
  tar -xpvf sealos_5.0.1_linux_amd64.tar.gz
  cp sealos sealctl image-cri-shim /usr/local/bin/
  if [ -f nerdctl ]; then
    cp nerdctl /usr/local/bin/
  fi
fi

# Load pre-packaged images if present
if [ -f "images/sealos-images.tar" ]; then
  if command -v sealos >/dev/null 2>&1; then
    sealos load -i images/sealos-images.tar || true
  elif command -v docker >/dev/null 2>&1; then
    docker load -i images/sealos-images.tar || true
  fi
fi

sealos run labring/kubernetes:v1.30.1 \
           labring/cilium:v1.18.1 \
           labring/helm:v3.16.2 \
           --masters "${NodeIP}" \
           --user root \
           --pk /root/.ssh/id_rsa \
           --env '{}' \
           --cmd 'kubeadm init --skip-phases=addon/kube-proxy'

#sealos add --nodes 172.31.23.69

helm repo add cilium https://helm.cilium.io
helm repo update
helm upgrade cilium cilium/cilium -n kube-system -f cilium-values.yaml --version 1.18.1
