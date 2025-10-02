#!/usr/bin/env bash
set -euo pipefail


if [[ -z "${REMOTE_ROOT:-}" || -z "${TAG_NAME:-}" || -z "${RSYNC_SSH_USER:-}" || -z "${VPS_HOST:-}" ]]; then
  echo "Missing required environment variables" >&2
  exit 1
fi


REMOTE_DIR="${REMOTE_ROOT}/${TAG_NAME}"
ssh -i ~/.ssh/id_rsa "${RSYNC_SSH_USER}@${VPS_HOST}" "mkdir -p '${REMOTE_DIR}'"
echo "Rsync -> ${VPS_HOST}:${REMOTE_DIR}/"
rsync -av -e "ssh -i ~/.ssh/id_rsa" \
  release-artifacts/amd64/offline-package-pulumi-amd64.tar.gz \
  release-artifacts/arm64/offline-package-pulumi-arm64.tar.gz \
  "${RSYNC_SSH_USER}@${VPS_HOST}:${REMOTE_DIR}/"
