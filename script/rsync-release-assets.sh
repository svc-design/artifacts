#!/usr/bin/env bash
set -euo pipefail

REMOTE_ROOT="${REMOTE_ROOT:?REMOTE_ROOT is required}"
TAG_NAME="${TAG_NAME:?TAG_NAME is required}"
RSYNC_SSH_USER="${RSYNC_SSH_USER:?RSYNC_SSH_USER is required}"
VPS_HOST="${VPS_HOST:?VPS_HOST is required}"

REMOTE_DIR="${REMOTE_ROOT}/${TAG_NAME}"
ssh -i ~/.ssh/id_rsa "${RSYNC_SSH_USER}@${VPS_HOST}" "mkdir -p '${REMOTE_DIR}'"
echo "Rsync -> ${VPS_HOST}:${REMOTE_DIR}/"
rsync -av -e "ssh -i ~/.ssh/id_rsa" \
  release-artifacts/amd64/offline-package-pulumi-amd64.tar.gz \
  release-artifacts/arm64/offline-package-pulumi-arm64.tar.gz \
  "${RSYNC_SSH_USER}@${VPS_HOST}:${REMOTE_DIR}/"
