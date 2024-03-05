#!/bin/bash

REGISTRY_ADDR=$1
REGISTRY_REPO_USER=$2
REGISTRY_REPO_PASSWORD=$3
DEBUG=${4:-false}

check_non_empty() {
    if [ -z "$1" ]; then
        echo "Error: $2 must be provided."
        exit 1
    fi
}

check_non_empty "$REGISTRY_ADDR" "Registry address"
check_non_empty "$REGISTRY_REPO_USER" "Registry username"
check_non_empty "$REGISTRY_REPO_PASSWORD" "Registry password"

mkdir -p /kaniko/.docker
AUTH=$(echo -n "${REGISTRY_REPO_USER}:${REGISTRY_REPO_PASSWORD}" | base64)
cat > /kaniko/.docker/config.json << EOF
{
  "auths": {
    "https://${REGISTRY_ADDR}/v1": {
      "auth": "${AUTH}"
    }
  }
}
EOF

if [ "$DEBUG" = "true" ]; then
    cat /kaniko/.docker/config.json
fi
