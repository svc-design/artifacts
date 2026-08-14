#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_NAME:?IMAGE_NAME must be set}"
: "${DOCKERFILE_PATH:?DOCKERFILE_PATH must be set}"

short_sha="$(git rev-parse --short HEAD)"
build_context="${BUILD_CONTEXT:-}"

if [[ -z "$build_context" ]]; then
  if [[ -d "$DOCKERFILE_PATH" ]]; then
    build_context="$DOCKERFILE_PATH"
    dockerfile="${DOCKERFILE_PATH}/Dockerfile"
  else
    build_context="."
    dockerfile="$DOCKERFILE_PATH"
  fi
else
  if [[ -d "$DOCKERFILE_PATH" ]]; then
    dockerfile="${DOCKERFILE_PATH}/Dockerfile"
  else
    dockerfile="$DOCKERFILE_PATH"
  fi
fi

echo "Building Docker image: ${IMAGE_NAME}:${short_sha} and ${IMAGE_NAME}:latest"
echo "  Context: ${build_context}"
echo "  Dockerfile: ${dockerfile}"

docker build \
  -t "${IMAGE_NAME}:${short_sha}" \
  -t "${IMAGE_NAME}:latest" \
  -f "${dockerfile}" \
  "${build_context}"

if [[ "${PUSH_IMAGE:-true}" == "true" ]]; then
  echo "Pushing Docker image: ${IMAGE_NAME}:${short_sha} and ${IMAGE_NAME}:latest"
  docker push "${IMAGE_NAME}:${short_sha}"
  docker push "${IMAGE_NAME}:latest"
fi
