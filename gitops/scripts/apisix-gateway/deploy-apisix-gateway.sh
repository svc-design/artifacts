#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <INGRESS_IP>"
  exit 1
fi

ingress_ip=$1

cat > values.yaml <<'EOF'
service:
  type: NodePort
  externalIPs:
    - __INGRESS_IP__
  http:
    enabled: true
    servicePort: 80
  tls:
    servicePort: 443
    nodePort: 30443

# 仅部署网关数据面；不装 etcd、不装 ingress-controller
etcd:
  enabled: false

ingress-controller:
  enabled: false

apisix:
  deployment:
    # standalone = 无 etcd，本地文件/ConfigMap 驱动；同时禁用 Admin API
    mode: standalone
    role: data_plane
    role_data_plane:
      # 需要时可用 yaml/json 作配置源；此处先保留 yaml
      config_provider: yaml

  # 基本特性可按需开启
  ssl:
    enabled: true
  prometheus:
    enabled: true

  # （可选加固）即便 Helm 仍创建了 Admin Service，standalone 下也不会有 Admin 监听；
  # 这里进一步把 Admin 访问白名单收紧，避免误触。
  admin:
    allow:
      ipList:
        - 127.0.0.1/32
EOF

# 注入外部 IP
sed -i'' -e "s#__INGRESS_IP__#${ingress_ip}#g" values.yaml 2>/dev/null || \
perl -pi -e "s#__INGRESS_IP__#${ingress_ip}#g" values.yaml

helm repo add apisix https://charts.apiseven.com || true
helm repo update
kubectl create ns ingress || true

# 只安装 APISIX 网关（无 etcd / 无 admin / 无 ingress-controller）
helm upgrade --install apisix apisix/apisix \
  --namespace ingress \
  -f values.yaml
