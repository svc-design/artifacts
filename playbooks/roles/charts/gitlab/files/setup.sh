#!/usr/bin/env bash
# Offline installer for GitLab Helm chart tailored for a single-node deployment.
# This script is designed to be embedded in the GitLab offline package and invoked as
#   bash install-gitlab.sh --version <VERSION> --domain <DOMAIN> [--namespace <NAMESPACE>]
# It renders a single-node friendly values file from the bundled template and installs
# the locally available GitLab Helm chart archive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/gitlab-offline.env"
DEFAULT_TEMPLATE="${SCRIPT_DIR}/gitlab-values.single-node.yaml"
DEFAULT_CHART_DIR="${SCRIPT_DIR}/charts"

log() { printf '[\033[32mINFO\033[0m] %s\n' "$*"; }
warn() { printf '[\033[33mWARN\033[0m] %s\n' "$*"; }
err() { printf '[\033[31mERROR\033[0m] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: install-gitlab.sh --version <version> --domain <domain> [options]

Options:
  --version, -v     GitLab chart version (required)
  --domain, -d      External domain name for GitLab (required)
  --namespace, -n   Kubernetes namespace to deploy into (default: gitlab)
  --config FILE     Configuration file (default: ./gitlab-offline.env if present)
  --values FILE     Values template to render (default: ./gitlab-values.single-node.yaml)
  --chart FILE      Explicit GitLab chart archive (*.tgz). Overrides --charts-dir.
  --charts-dir DIR  Directory that contains the GitLab chart archive (default: ./charts)
  --skip-image-load Skip loading container images from ./images
  --help, -h        Show this help and exit

Environment variables (overridable via --config or CLI):
  GITLAB_VERSION    Same as --version
  GITLAB_DOMAIN     Same as --domain
  GITLAB_NAMESPACE  Same as --namespace
  GITLAB_CHART      Same as --chart
  GITLAB_CHARTS_DIR Same as --charts-dir
  GITLAB_VALUES     Same as --values
  SKIP_IMAGE_LOAD   Same as --skip-image-load
USAGE
}

load_config_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # shellcheck disable=SC1090
  source "$file"
}

parse_args() {
  local args=("$@")
  local config_file="$DEFAULT_CONFIG_FILE"

  for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[i]}" == "--config" ]]; then
      (( i + 1 < ${#args[@]} )) || err "--config requires a value"
      config_file="${args[i+1]}"
      break
    fi
  done

  load_config_file "$config_file"

  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[i]}" in
      --version|-v)
        (( i + 1 < ${#args[@]} )) || err "--version requires a value"
        GITLAB_VERSION="${args[i+1]}"
        ((i+=2))
        ;;
      --domain|-d)
        (( i + 1 < ${#args[@]} )) || err "--domain requires a value"
        GITLAB_DOMAIN="${args[i+1]}"
        ((i+=2))
        ;;
      --namespace|-n)
        (( i + 1 < ${#args[@]} )) || err "--namespace requires a value"
        GITLAB_NAMESPACE="${args[i+1]}"
        ((i+=2))
        ;;
      --config)
        ((i+=2))
        ;;
      --values)
        (( i + 1 < ${#args[@]} )) || err "--values requires a value"
        GITLAB_VALUES="${args[i+1]}"
        ((i+=2))
        ;;
      --chart)
        (( i + 1 < ${#args[@]} )) || err "--chart requires a value"
        GITLAB_CHART="${args[i+1]}"
        ((i+=2))
        ;;
      --charts-dir)
        (( i + 1 < ${#args[@]} )) || err "--charts-dir requires a value"
        GITLAB_CHARTS_DIR="${args[i+1]}"
        ((i+=2))
        ;;
      --skip-image-load)
        SKIP_IMAGE_LOAD="1"
        ((i+=1))
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: ${args[i]}"
        ;;
    esac
  done
}

check_prerequisites() {
  command -v helm >/dev/null 2>&1 || err "helm is required"
  command -v kubectl >/dev/null 2>&1 || err "kubectl is required"
  command -v envsubst >/dev/null 2>&1 || err "envsubst (gettext) is required"
}

pick_loader() {
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      echo "docker"
      return
    fi
  fi
  if command -v nerdctl >/dev/null 2>&1; then
    if nerdctl info >/dev/null 2>&1; then
      echo "nerdctl"
      return
    fi
  fi
  if command -v ctr >/dev/null 2>&1; then
    echo "ctr"
    return
  fi
  echo ""
}

load_offline_images() {
  local images_dir="$SCRIPT_DIR/images"
  [[ "${SKIP_IMAGE_LOAD:-0}" == "1" ]] && { warn "Skipping image import as requested"; return 0; }
  [[ -d "$images_dir" ]] || { warn "No images directory found (expected ${images_dir})"; return 0; }
  shopt -s nullglob
  local archives=("${images_dir}"/*.tar "${images_dir}"/*.tar.gz)
  shopt -u nullglob
  [[ ${#archives[@]} -gt 0 ]] || { warn "No container image archives found in ${images_dir}"; return 0; }

  local loader; loader="$(pick_loader)"
  [[ -n "$loader" ]] || err "Unable to locate docker, nerdctl, or ctr for loading images"

  log "Loading offline container images using ${loader}"
  for archive in "${archives[@]}"; do
    case "$loader" in
      docker) docker load -i "$archive" ;;
      nerdctl) nerdctl load -i "$archive" ;;
      ctr) ctr -n k8s.io images import "$archive" ;;
    esac
  done
}

render_values_file() {
  local template="$1" output="$2"
  [[ -f "$template" ]] || err "Values template not found: $template"
  export GITLAB_DOMAIN GITLAB_NAMESPACE
  envsubst '${GITLAB_DOMAIN}${GITLAB_NAMESPACE}' < "$template" > "$output"
}

select_chart() {
  if [[ -n "${GITLAB_CHART:-}" ]]; then
    [[ -f "$GITLAB_CHART" ]] || err "Specified chart not found: $GITLAB_CHART"
    echo "$GITLAB_CHART"
    return
  fi
  local charts_dir="${GITLAB_CHARTS_DIR:-$DEFAULT_CHART_DIR}"
  local chart_archive="${charts_dir}/gitlab-${GITLAB_VERSION}.tgz"
  [[ -f "$chart_archive" ]] || err "GitLab chart archive not found: $chart_archive"
  echo "$chart_archive"
}

ensure_namespace() {
  if ! kubectl get namespace "$GITLAB_NAMESPACE" >/dev/null 2>&1; then
    log "Creating namespace ${GITLAB_NAMESPACE}"
    kubectl create namespace "$GITLAB_NAMESPACE"
  fi
}

main() {
  parse_args "$@"
  check_prerequisites

  [[ -n "${GITLAB_VERSION:-}" ]] || err "GitLab chart version is required (--version)"
  [[ -n "${GITLAB_DOMAIN:-}" ]] || err "Domain is required (--domain)"
  GITLAB_NAMESPACE="${GITLAB_NAMESPACE:-gitlab}"

  local values_template="${GITLAB_VALUES:-$DEFAULT_TEMPLATE}"
  local tmp_values
  tmp_values="$(mktemp)"
  trap 'rm -f "$tmp_values"' EXIT

  render_values_file "$values_template" "$tmp_values"
  load_offline_images

  ensure_namespace

  local chart_archive
  chart_archive="$(select_chart)"

  log "Installing GitLab ${GITLAB_VERSION} into namespace ${GITLAB_NAMESPACE}"
  helm upgrade --install gitlab "$chart_archive" \
    --namespace "$GITLAB_NAMESPACE" \
    --create-namespace \
    --values "$tmp_values" \
    --timeout 15m \
    --wait \
    --debug

  log "GitLab installation triggered successfully"
}

main "$@"
