#!/usr/bin/env bash
set -euo pipefail

# 1) 起集群：去掉 labring/cilium，只保留 K8s + Helm，并跳过 kube-proxy
sealos run labring/kubernetes:v1.29.9 \
           labring/helm:v3.9.4 \
           --masters 192.168.124.77 \
           --user root \
           --pk /root/.ssh/id_rsa \
           --env '{}' \
           --cmd 'kubeadm init --skip-phases=addon/kube-proxy'

# 2) 安装 Cilium：使用 Helm 指定 chart 1.18.1（稳定）
helm repo add cilium https://helm.cilium.io
helm repo update
helm upgrade --install cilium cilium/cilium \
  -n kube-system \
  --version 1.18.1 \
  -f cilium-values.yaml

# 可选：等待就绪（方便 CI/一键脚本）
kubectl -n kube-system rollout status ds/cilium --timeout=10m || true
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=5m || true

# 查看状态
cilium status || true
