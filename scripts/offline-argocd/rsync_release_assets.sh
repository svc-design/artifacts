#!/usr/bin/env bash
set -euo pipefail

REMOTE_DIR="${REMOTE_ROOT:?REMOTE_ROOT environment variable is required}/${TAG_NAME:?TAG_NAME environment variable is required}"
SSH_USER="${RSYNC_SSH_USER:?RSYNC_SSH_USER environment variable is required}"
HOST="${VPS_HOST:?VPS_HOST environment variable is required}"

ssh -i ~/.ssh/id_rsa "${SSH_USER}@${HOST}" "mkdir -p '${REMOTE_DIR}'"
echo "Rsync -> ${HOST}:${REMOTE_DIR}/"
rsync -av -e "ssh -i ~/.ssh/id_rsa" \
  release-artifacts/amd64/offline-package-argocd-amd64.tar.gz \
  release-artifacts/arm64/offline-package-argocd-arm64.tar.gz \
  "${SSH_USER}@${HOST}:${REMOTE_DIR}/"
