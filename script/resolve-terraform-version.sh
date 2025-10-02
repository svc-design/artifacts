#!/usr/bin/env bash
set -euo pipefail

OVERRIDE_VERSION="${OVERRIDE_VERSION:-}"
if [[ -n "${OVERRIDE_VERSION}" ]]; then
  VERSION="${OVERRIDE_VERSION}"
else
  VERSION=$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')
fi

echo "Resolved Terraform version: ${VERSION}"
echo "version=${VERSION}" >> "${GITHUB_OUTPUT}"
