#!/usr/bin/env bash
set -euo pipefail

CHART_VERSION="${CHART_VERSION:?CHART_VERSION environment variable is required}"
MATRIX_ARCH="${MATRIX_ARCH:?MATRIX_ARCH environment variable is required}"

PLATFORM="linux/${MATRIX_ARCH}"

temp_manifest=$(mktemp)
trap 'rm -f "${temp_manifest}"' EXIT

helm template argo argo/argo-cd --version "${CHART_VERSION}" > "${temp_manifest}"
mapfile -t images < <(grep -oP 'image:\s*"?\K([^"\s]+)' "${temp_manifest}" | sort -u || true)

for img in "${images[@]}"; do
  [ -n "$img" ] || continue
  if [[ "$img" == *"{{"* ]]; then
    continue
  fi
  echo "Pulling $img for ${PLATFORM}"
  if ! docker pull --platform "${PLATFORM}" "$img"; then
    echo "::warning::Failed to pull $img for ${PLATFORM}, skipping" >&2
    continue
  fi
  safe=$(echo "$img" | tr '/:' '-_')
  docker save "$img" -o "argocd-offline-package/images/${safe}.tar"
done
