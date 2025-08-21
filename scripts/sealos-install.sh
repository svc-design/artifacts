#!/bin/bash
set -euo pipefail

# Load pre-packaged images if present
if [ -f "images/sealos-images.tar" ]; then
  if command -v sealos >/dev/null 2>&1; then
    sealos load -i images/sealos-images.tar || true
  elif command -v docker >/dev/null 2>&1; then
    docker load -i images/sealos-images.tar || true
  fi
fi

sealos run labring/kubernetes:v1.29.9 \
           labring/cilium:v1.13.4 \
           labring/helm:v3.9.4 \
           --masters 172.31.23.68 \
           --user root \
           --pk /root/.ssh/id_rsa \
           --env '{}' \
           --cmd 'kubeadm init --skip-phases=addon/kube-proxy'

sealos add --nodes 172.31.23.69

helm repo add cilium https://helm.cilium.io
helm repo update
helm upgrade cilium cilium/cilium -n kube-system -f cilium-values.yaml
