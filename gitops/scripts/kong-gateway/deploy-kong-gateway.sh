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
    - onwalk-tls
  env:
    ssl_cert: /etc/secrets/onwalk-tls/tls.crt
    ssl_cert_key: /etc/secrets/onwalk-tls/tls.key
VEOF

kubectl create ns kong || true
kubectl create secret tls onwalk-tls --cert=/etc/ssl/onwalk.net.pem --key=/etc/ssl/onwalk.net.key -n kong
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

kubectl patch svc kong-gateway-proxy -n kong \
  --type='merge' \
  -p '{
    "spec": {
      "externalIPs": [
        "47.120.61.35"
      ]
    }
  }'

kubectl patch deployment kong-gateway -n kong \
  --type='merge' \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "nodeName": "icp-aliyun.svc.plus"
        }
      }
    }
  }'

# Configure GatewayClass and example application
cat <<'YEOF' | kubectl apply -f -
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
 name: kong
 annotations:
   konghq.com/gatewayclass-unmanaged: 'true'

spec:
 controllerName: konghq.com/kic-gateway-controller
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  namespace: default
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-gateway
  namespace: default
  annotations:
    konghq.com/publish-service: kong/kong-gateway-proxy
spec:
  gatewayClassName: kong
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      hostname: "demo.onwalk.net"
      tls:
        mode: Terminate
        certificateRefs:
          - name: onwalk-tls
      allowedRoutes:
        namespaces:
          from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo-route
  namespace: default
spec:
  parentRefs:
    - name: demo-gateway
      namespace: default
  hostnames:
    - demo.onwalk.net
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: nginx-svc
          port: 80
YEOF

kubectl label nodes icp-aliyun.svc.plus ingress-node=true

curl -ksv https://demo.onwalk.net/ --resolve demo.onwalk.net:443:172.30.0.10
