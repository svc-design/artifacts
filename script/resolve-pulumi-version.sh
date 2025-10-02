#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${OVERRIDE_VERSION:-}" ]]; then
  VERSION="${OVERRIDE_VERSION}"
else
  VERSION=$(curl -fsSL https://api.github.com/repos/pulumi/pulumi/releases?per_page=100 \
    | jq -r '.[].tag_name' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sed 's/^v//' \
    | sort -V \
    | tail -n 1)
fi

if [[ -z "${VERSION}" ]]; then
  echo "Failed to resolve Pulumi version" >&2
  exit 1
fi

echo "Resolved Pulumi version: ${VERSION}"
echo "version=${VERSION}" >> "${GITHUB_OUTPUT}"
