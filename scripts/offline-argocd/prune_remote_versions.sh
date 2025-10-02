#!/usr/bin/env bash
set -euo pipefail

SSH_USER="${RSYNC_SSH_USER:?RSYNC_SSH_USER environment variable is required}"
HOST="${VPS_HOST:?VPS_HOST environment variable is required}"
REMOTE_ROOT="${REMOTE_ROOT:?REMOTE_ROOT environment variable is required}"

ssh -i ~/.ssh/id_rsa "${SSH_USER}@${HOST}" REMOTE_ROOT="${REMOTE_ROOT}" 'bash -s' <<'EOS'
set -euo pipefail
cd "${REMOTE_ROOT}" || exit 0
keep=3
mapfile -t all < <(ls -1 | grep -E "^(offline-argocd-|v[0-9]+\.)" | sort -V -r || true)
if [ "${#all[@]}" -le "$keep" ]; then
  echo "Nothing to prune. Count=${#all[@]}"
  exit 0
fi
to_delete=("${all[@]:keep}")
echo "Pruning old versions: ${to_delete[*]}"
for d in "${to_delete[@]}"; do
  rm -rf -- "$d"
done
EOS
