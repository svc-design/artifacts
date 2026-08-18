# Distributed Web SaaS Fullstack Chart

This is a standalone umbrella Chart for an open/self-hosted, distributed Web
SaaS installation on K3s or Kubernetes. It deliberately does not depend on the
legacy `web-saas` chart, whose subcharts are an earlier scaffold.

## Components

```text
Ingress (Traefik or Caddy)
  -> frontend-router
     -> static-assets, SSR auth/content/console/workspace/public
     -> edge-gateway-router
        -> edge-gateway-auth, edge-gateway-admin, edge-gateway-core
           -> accounts, content, billing, PostgreSQL
```

`edge-gateway-router` is an internal Caddy path router. Cloudflare provides
this behaviour through Worker Route precedence; Kubernetes requires it to be
declared explicitly. `edge-gateway-core` remains the stable fallback Worker
role and is displayed as **Edge Gateway Router Core**.

## K3s open profile

1. Build and publish every application image with the same immutable tag.
2. Create the PostgreSQL Secret and the runtime Secret (or configure Vault CSI
   / External Secrets). Do not put either value in Helm values.
3. Replace `daily-build-REPLACE_ME` in `values-open.yaml` with the selected
   immutable tag and set image repositories if your registry differs.
4. Install with `helm upgrade --install ... -f values-open.yaml`.

The default profile is intentionally single replica, ClusterIP-only, Traefik
Ingress, and one PostgreSQL StatefulSet with a K3s `local-path` PVC. Its
database image is `ghcr.io/ai-workspace-infra/postgresql:17`, built and
published by `ai-workspace-services/postgresql.svc.plus`; do not replace it
with the generic upstream PostgreSQL image. HA, HPA, external/self-hosted
Supabase, Vault injection, and NetworkPolicy are later production profiles;
migrations remain controlled by the delivery `operation`, not Helm lifecycle
hooks.
