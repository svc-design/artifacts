#!/usr/bin/env bash
# scripts/resolve_k3s_versions.sh
# 输出：写入 $GITHUB_OUTPUT -> version, recent_versions
# 环境变量：
#   OVERRIDE_VERSION  可选，手工覆盖版本（如 v1.33.4+k3s1）
#   GITHUB_TOKEN      可选，避免匿名限速

set -euo pipefail

OVERRIDE_VERSION="${OVERRIDE_VERSION:-}"

API_URL="https://api.github.com/repos/k3s-io/k3s/releases?per_page=100"
COMMON_HEADERS=(
  -H "Accept: application/vnd.github+json"
  -H "User-Agent: resolve_k3s_versions"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  COMMON_HEADERS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

fetch_releases() {
  # 如果触发限流，给出清晰错误
  local body
  set +e
  body="$(curl -fsSL "${COMMON_HEADERS[@]}" "${API_URL}")"
  local rc=$?
  set -e
  if [[ $rc -ne 0 || -z "$body" ]]; then
    echo "ERROR: failed to fetch GitHub releases." >&2
    exit 1
  fi
  if grep -q '"API rate limit exceeded"' <<<"$body"; then
    echo "ERROR: GitHub API rate limit exceeded. Provide GITHUB_TOKEN." >&2
    exit 1
  fi
  printf '%s' "$body"
}

resolve_latest() {
  if [[ -n "${OVERRIDE_VERSION}" ]]; then
    echo "${OVERRIDE_VERSION}"
    return
  fi
  fetch_releases | jq -r '
    [ .[] | select(.prerelease==false and .draft==false) ]
    | sort_by(.published_at) | last | .tag_name
  '
}

resolve_recent() {
  fetch_releases | jq -r '
    [ .[] | select(.prerelease==false and .draft==false) ]
    | sort_by(.published_at) | reverse
    | .[0:3] | map(.tag_name) | @tsv
  '
}

LATEST="$(resolve_latest)"
RECENT="$(resolve_recent)"

# 兼容本地执行：若 $GITHUB_OUTPUT 未设置，则写到 /tmp
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/tmp/resolve_k3s_versions.out}"
{
  echo "version=${LATEST}"
  echo "recent_versions=${RECENT}"
} >> "${GITHUB_OUTPUT}"

echo "Resolved latest stable k3s version: ${LATEST}"
echo "Recent versions: ${RECENT}"
