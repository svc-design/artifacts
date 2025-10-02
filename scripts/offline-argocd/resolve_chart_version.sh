#!/usr/bin/env bash
set -euo pipefail

OVERRIDE_CHART_VERSION="${OVERRIDE_CHART_VERSION:-}"
if [[ -n "${OVERRIDE_CHART_VERSION}" ]]; then
  CHART_VERSION="${OVERRIDE_CHART_VERSION}"
else
  CHART_VERSION=$(helm search repo argo/argo-cd --versions | awk 'NR==2{print $2}')
fi

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "GITHUB_OUTPUT environment variable is not set" >&2
  exit 1
fi

echo "chart_version=${CHART_VERSION}" >> "${GITHUB_OUTPUT}"
