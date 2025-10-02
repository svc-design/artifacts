#!/usr/bin/env bash
set -euo pipefail

REMOTE_DIR="${REMOTE_ROOT}/${TAG_NAME}"
ssh -i ~/.ssh/id_rsa "${RSYNC_SSH_USER}@${VPS_HOST}" "mkdir -p '${REMOTE_DIR}'"
echo "Rsync -> ${VPS_HOST}:${REMOTE_DIR}/"
rsync -av -e "ssh -i ~/.ssh/id_rsa" \
  release-artifacts/amd64/terraform-offline-package-amd64.tar.gz \
  release-artifacts/arm64/terraform-offline-package-arm64.tar.gz \
  "${RSYNC_SSH_USER}@${VPS_HOST}:${REMOTE_DIR}/"
