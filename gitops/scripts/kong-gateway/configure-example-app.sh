#!/usr/bin/env bash
set -euo pipefail

NODE_NAME=$(hostname)
kubectl label nodes "${NODE_NAME}" ingress-node=true --overwrite

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
      hostname: "example.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: example-tls
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
    - example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: nginx-svc
          port: 80
YEOF

EXTERNAL_IP=$(hostname -I | awk '{print $1}')
curl -ksv https://example.com --resolve example.com:443:${EXTERNAL_IP}
