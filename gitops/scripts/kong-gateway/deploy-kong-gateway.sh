#!/usr/bin/env bash
set -euo pipefail

# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# Setup Helm repository and values
helm repo add kong https://charts.konghq.com
helm repo update
cat > kong-values.yaml <<'VEOF'
kong:
  secretVolumes:
    - example-tls
  env:
    ssl_cert: /etc/secrets/example-tls/tls.crt
    ssl_cert_key: /etc/secrets/example-tls/tls.key
VEOF

kubectl create ns kong || true

# Generate self-signed certificate for example.com
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/CN=example.com" \
  -keyout example.com.key \
  -out example.com.pem

kubectl create secret tls example-tls --cert=example.com.pem --key=example.com.key -n kong
helm upgrade --install kong kong/ingress -n kong --create-namespace -f kong-values.yaml

# Expose Kong proxy via NodePort and external IP
kubectl patch svc kong-gateway-proxy -n kong \
  --type='merge' \
  -p '{
    "spec": {
      "type": "NodePort",
      "ports": [
        {
          "port": 80,
          "targetPort": 8000,
          "protocol": "TCP",
          "name": "http",
          "nodePort": 80
        },
        {
          "port": 443,
          "targetPort": 8443,
          "protocol": "TCP",
          "name": "https",
          "nodePort": 443
        }
      ]
    }
  }'

EXTERNAL_IP=$(hostname -I | awk '{print $1}')
kubectl patch svc kong-gateway-proxy -n kong \
  --type='merge' \
  -p "{\"spec\": {\"externalIPs\": [\"${EXTERNAL_IP}\"]}}"

NODE_NAME=$(hostname)
kubectl patch deployment kong-gateway -n kong \
  --type='merge' \
  -p "{\"spec\": {\"template\": {\"spec\": {\"nodeName\": \"${NODE_NAME}\"}}}}"
