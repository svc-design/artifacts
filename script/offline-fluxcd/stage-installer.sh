#!/usr/bin/env bash
set -euo pipefail

: "${CHART_VERSION?CHART_VERSION is required}"

rm -f offline-installer/scripts/install-fluxcd.sh
override_dir="offline-installer"
mkdir -p "${override_dir}/scripts" "${override_dir}/metadata"

cat <<'SCRIPT' > "${override_dir}/scripts/install-fluxcd.sh"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT_DIR}/charts/flux2"
IMAGES_DIR="${ROOT_DIR}/images"
RELEASE_NAME="${RELEASE_NAME:-flux-system}"
NAMESPACE="${NAMESPACE:-flux-system}"

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

echo "Installing/Upgrading FluxCD release ${RELEASE_NAME} in namespace ${NAMESPACE}"
helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  "$@"
SCRIPT
chmod +x "${override_dir}/scripts/install-fluxcd.sh"

cat <<EOF_META > "${override_dir}/metadata/INFO"
chart: fluxcd-community/flux2
chart_version: ${CHART_VERSION}
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF_META
