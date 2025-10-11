#!/usr/bin/env bash
set -euo pipefail

APP_NAME="n8n"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OFFLINE_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
COMPOSE_FILE="${OFFLINE_ROOT}/docker-compose.yaml"
IMAGES_DIR="${OFFLINE_ROOT}/images"
IMAGE_LOAD_TOOL="${IMAGE_LOAD_TOOL:-docker}"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

load_images() {
  if ! command_exists "${IMAGE_LOAD_TOOL}"; then
    echo "Error: image loader '${IMAGE_LOAD_TOOL}' not found in PATH" >&2
    exit 1
  fi

  if [ ! -d "${IMAGES_DIR}" ]; then
    echo "No images directory found at ${IMAGES_DIR}. Skipping image load." >&2
    return
  fi

  shopt -s nullglob
  local tarball
  for tarball in "${IMAGES_DIR}"/*.tar; do
    echo "Loading container images from ${tarball}"
    "${IMAGE_LOAD_TOOL}" load -i "${tarball}"
  done
  shopt -u nullglob
}

compose() {
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command_exists docker-compose; then
    docker-compose "$@"
  else
    echo "Error: docker compose plugin or docker-compose binary is required" >&2
    exit 1
  fi
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [command]

Commands:
  up             Load images (if available) and start ${APP_NAME}
  down           Stop ${APP_NAME}
  load-images    Only load container images from the images/ directory
  status         Show status of the compose application

Environment variables:
  IMAGE_LOAD_TOOL   Override the container image loader (default: docker)
  COMPOSE_FILE      Override docker compose file path (default: ${COMPOSE_FILE})
USAGE
}

cmd=${1:-up}
case "${cmd}" in
  up)
    load_images
    compose -f "${COMPOSE_FILE}" up -d
    ;;
  down)
    compose -f "${COMPOSE_FILE}" down
    ;;
  load-images)
    load_images
    ;;
  status)
    compose -f "${COMPOSE_FILE}" ps
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    exit 1
    ;;
esac
