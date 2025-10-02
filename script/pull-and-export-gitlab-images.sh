#!/usr/bin/env bash
set -euo pipefail

CHART_VERSION="${CHART_VERSION:?CHART_VERSION is required}"
ARCH="${ARCH:?ARCH is required}"
PLATFORM="linux/${ARCH}"

helm template gitlab gitlab/gitlab --version "${CHART_VERSION}" > manifest.yaml
mapfile -t images < <(grep -oP 'image:\s*"?\K([^"\s]+)' manifest.yaml | sort -u || true)
rm -f manifest.yaml

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
  docker save "$img" -o "offline-installer/images/${safe}.tar"
done
