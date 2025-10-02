#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-}"
if [[ -z "${ARCH}" ]]; then
  echo "ARCH environment variable is required" >&2
  exit 1
fi

cd test-dir/terraform-offline-package

test -f VERSION

if [[ "${ARCH}" == "amd64" ]]; then
  ./bin/terraform version
  ./bin/terraform version | grep "Terraform v${TERRAFORM_VERSION}"
else
  file ./bin/terraform | grep -E "ARM|aarch64"
fi
