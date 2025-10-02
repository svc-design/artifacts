#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${REMOTE_ROOT:-}" || -z "${RSYNC_SSH_USER:-}" || -z "${VPS_HOST:-}" ]]; then
  echo "Missing required environment variables" >&2
  exit 1
fi

ssh -i ~/.ssh/id_rsa "${RSYNC_SSH_USER}@${VPS_HOST}" bash -lc '
  set -euo pipefail
  cd "'"'${REMOTE_ROOT}'"'" || exit 0
  keep=3
  mapfile -t all < <(ls -1 | grep -E "^(offline-pulumi-|v[0-9]+\.)" | sort -V -r || true)
  if [[ "${#all[@]}" -le "${keep}" ]]; then
    echo "Nothing to prune. Count=${#all[@]}"
    exit 0
  fi
  to_delete=("${all[@]:keep}")
  echo "Pruning old versions: ${to_delete[*]}"
  for d in "${to_delete[@]}"; do
    rm -rf -- "$d"
  done
'
