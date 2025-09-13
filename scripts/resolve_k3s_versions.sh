#!/usr/bin/env bash
# scripts/resolve_k3s_versions.sh
# 输出：写入 $GITHUB_OUTPUT -> version, recent_versions
# 环境变量：
#   OVERRIDE_VERSION  可选，手工覆盖版本（如 v1.30.0+k3s1）

set -euo pipefail

OVERRIDE_VERSION="${OVERRIDE_VERSION:-}"

API_URL="https://api.github.com/repos/k3s-io/k3s/releases?per_page=100"
COMMON_HEADERS=(-H "Accept: application/vnd.github+json" -H "User-Agent: resolve_k3s_versions")
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  COMMON_HEADERS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

resolve_latest() {
  if [[ -n "${OVERRIDE_VERSION}" ]]; then
    echo "${OVERRIDE_VERSION}"
    return
  fi

  curl -fsSL "${COMMON_HEADERS[@]}" "${API_URL}" \
    | jq -r '[.[] | select(.prerelease==false and .draft==false) | .tag_name] | sort -V | last'
}

resolve_recent() {
  curl -fsSL "${COMMON_HEADERS[@]}" "${API_URL}" \
    | jq -r '[.[] | select(.prerelease==false and .draft==false) | .tag_name] | sort -V | reverse | .[0:3] | @tsv'
}

LATEST="$(resolve_latest)"
RECENT="$(resolve_recent)"

{
  echo "version=${LATEST}"
  echo "recent_versions=${RECENT}"
} >> "${GITHUB_OUTPUT}"

echo "Resolved latest stable k3s version: ${LATEST}"
echo "Recent versions: ${RECENT}"
