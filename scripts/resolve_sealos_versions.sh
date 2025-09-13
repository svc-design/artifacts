#!/usr/bin/env bash
# scripts/resolve_sealos_versions.sh
# 输出：写入 $GITHUB_OUTPUT -> sealos_version
# 环境变量：
#   OVERRIDE_SEALOS_VERSION 可选，手工指定 Sealos 版本（如 5.0.3）

set -euo pipefail

OVERRIDE_SEALOS_VERSION="${OVERRIDE_SEALOS_VERSION:-}"

resolve_version() {
  if [[ -n "${OVERRIDE_SEALOS_VERSION}" ]]; then
    echo "${OVERRIDE_SEALOS_VERSION}"
    return
  fi

  latest="$(curl -fsSL https://api.github.com/repos/labring/sealos/releases/latest | jq -r '.tag_name')"
  latest="${latest#v}"

  if [[ -z "${latest}" ]]; then
    echo "Failed to resolve latest Sealos version" >&2
    exit 1
  fi
  echo "${latest}"
}

SEALOS_VERSION="$(resolve_version)"
{
  echo "sealos_version=${SEALOS_VERSION}"
} >> "${GITHUB_OUTPUT}"

echo "Resolved => Sealos ${SEALOS_VERSION}"
