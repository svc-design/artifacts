#!/usr/bin/env bash
set -euo pipefail


ARCH="${MATRIX_ARCH:-}"
if [[ -z "${ARCH}" ]]; then
  echo "MATRIX_ARCH environment variable is required" >&2
  exit 1
fi

cd test-dir/pulumi-offline-package

test -f VERSION


if [[ "${ARCH}" == "amd64" ]]; then
  ./bin/pulumi version
  ./bin/pulumi version | grep "v${PULUMI_VERSION}"
else
  file ./bin/pulumi | grep -E "ARM|aarch64"
fi
