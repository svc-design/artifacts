#!/usr/bin/env bash
set -euo pipefail

CHART_VERSION="${CHART_VERSION:?CHART_VERSION environment variable is required}"

cat <<'SCRIPT' > argocd-offline-package/scripts/install-argocd.sh
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT_DIR}/charts/argo-cd"
IMAGES_DIR="${ROOT_DIR}/images"
RELEASE_NAME="${RELEASE_NAME:-argo-cd}"
NAMESPACE="${NAMESPACE:-argocd}"

if command -v nerdctl >/dev/null 2>&1; then
  LOADER="nerdctl"
elif command -v docker >/dev/null 2>&1; then
  LOADER="docker"
else
  echo "Either docker or nerdctl is required to load images." >&2
  exit 1
fi

for tar in "${IMAGES_DIR}"/*.tar; do
  [ -f "$tar" ] || continue
  echo "Loading image: $tar"
  "$LOADER" load -i "$tar"
done

echo "Installing/Upgrading Argo CD release ${RELEASE_NAME} in namespace ${NAMESPACE}"
helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  "$@"
SCRIPT

chmod +x argocd-offline-package/scripts/install-argocd.sh

cat <<EOFMETA > argocd-offline-package/metadata/INFO
chart: argo/argo-cd
chart_version: ${CHART_VERSION}
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOFMETA
