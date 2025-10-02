#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update -y
sudo apt-get install -y curl jq
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
