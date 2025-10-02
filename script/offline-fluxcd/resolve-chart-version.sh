#!/usr/bin/env bash
set -euo pipefail

OVERRIDE_CHART_VERSION="${OVERRIDE_CHART_VERSION:-}" # compatibility
if [[ -n "${OVERRIDE_CHART_VERSION}" ]]; then
  CHART_VERSION="${OVERRIDE_CHART_VERSION}"
else
  CHART_VERSION=$(helm search repo fluxcd-community/flux2 --versions | awk 'NR==2{print $2}')
fi

echo "chart_version=${CHART_VERSION}" >> "${GITHUB_OUTPUT}"
