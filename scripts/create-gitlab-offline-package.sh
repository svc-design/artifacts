#!/usr/bin/env bash
# Build the GitLab offline package archive.
# Usage: GITLAB_VERSION=<version> scripts/create-gitlab-offline-package.sh
# Environment variables:
#   GITLAB_VERSION   (required) GitLab Helm chart version, e.g. 7.8.0
#   ARCH             Target architecture suffix for the archive name (default: amd64)
#   INCLUDE_IMAGES   If set to 1, pull GitLab images and bundle them into the package (requires docker)
#   WORKDIR          Working directory name (default: gitlab-offline-package)

set -euo pipefail

log() { printf '[\033[32mINFO\033[0m] %s\n' "$*"; }
warn() { printf '[\033[33mWARN\033[0m] %s\n' "$*"; }
err() { printf '[\033[31mERROR\033[0m] %s\n' "$*" >&2; exit 1; }

command -v helm >/dev/null 2>&1 || err "helm is required to build the offline package"

GITLAB_VERSION="${GITLAB_VERSION:-}"
[[ -n "$GITLAB_VERSION" ]] || err "GITLAB_VERSION is required"

ARCH="${ARCH:-amd64}"
WORKDIR="${WORKDIR:-gitlab-offline-package}"
INCLUDE_IMAGES="${INCLUDE_IMAGES:-0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES_DIR="${ROOT_DIR}/playbooks/roles/charts/gitlab/files"
VALUES_TEMPLATE="${FILES_DIR}/gitlab-values.single-node.yaml"
INSTALLER_SCRIPT="${FILES_DIR}/setup.sh"
WRAPPER_SCRIPT="${FILES_DIR}/install-gitlab.sh"
ENV_EXAMPLE="${FILES_DIR}/gitlab-offline.env.example"

[[ -f "$VALUES_TEMPLATE" ]] || err "Values template missing: $VALUES_TEMPLATE"
[[ -f "$INSTALLER_SCRIPT" ]] || err "Installer script missing: $INSTALLER_SCRIPT"
[[ -f "$WRAPPER_SCRIPT" ]] || err "Wrapper script missing: $WRAPPER_SCRIPT"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/charts"

log "Pulling GitLab Helm chart ${GITLAB_VERSION}"
helm repo add gitlab https://charts.gitlab.io/ >/dev/null
helm repo update >/dev/null
helm pull gitlab/gitlab --version "$GITLAB_VERSION" --destination "$WORKDIR/charts"

log "Copying installer assets"
cp "$INSTALLER_SCRIPT" "$WORKDIR/setup.sh"
cp "$WRAPPER_SCRIPT" "$WORKDIR/install-gitlab.sh"
cp "$FILES_DIR/gitlab-values.single-node.yaml" "$WORKDIR/gitlab-values.single-node.yaml"
cp "$ENV_EXAMPLE" "$WORKDIR/gitlab-offline.env.example"
chmod +x "$WORKDIR/setup.sh" "$WORKDIR/install-gitlab.sh"

cat > "$WORKDIR/README.md" <<'DOC'
# GitLab Offline Package

## Usage

```
tar -xvpf offline-package-gitlab-<arch>.tar.gz
cd gitlab-offline-package/
cp gitlab-offline.env.example gitlab-offline.env
# Adjust gitlab-offline.env then run:
bash install-gitlab.sh --version <VERSION> --domain <DOMAIN> [--namespace <NAMESPACE>]
```

If container images are bundled, they can be imported automatically. Set
`SKIP_IMAGE_LOAD=1` in `gitlab-offline.env` to skip loading.
DOC

bundle_images() {
  local chart_archive="$WORKDIR/charts/gitlab-${GITLAB_VERSION}.tgz"
  local tmp_values tmp_manifest
  tmp_values="$(mktemp)"
  tmp_manifest="$(mktemp)"
  trap 'rm -f "$tmp_values" "$tmp_manifest"' RETURN

  export GITLAB_DOMAIN="gitlab.example.com" GITLAB_NAMESPACE="gitlab"
  envsubst '${GITLAB_DOMAIN}${GITLAB_NAMESPACE}' < "$VALUES_TEMPLATE" > "$tmp_values"
  helm template gitlab "$chart_archive" -f "$tmp_values" > "$tmp_manifest"

  mapfile -t images < <(awk '/image:/{print $2}' "$tmp_manifest" | sed 's/"//g' | sort -u)
  if [[ ${#images[@]} -eq 0 ]]; then
    warn "No images detected; skipping image bundle"
    return
  fi

  command -v docker >/dev/null 2>&1 || err "docker is required to bundle images"
  mkdir -p "$WORKDIR/images"

  for image in "${images[@]}"; do
    log "Pulling $image"
    docker pull --platform "linux/${ARCH}" "$image"
  done

  local image_tar="$WORKDIR/images/gitlab-images-${ARCH}.tar"
  log "Saving images to ${image_tar}"
  docker save -o "$image_tar" "${images[@]}"
  printf '%s\n' "${images[@]}" > "$WORKDIR/images/images.txt"
}

if [[ "$INCLUDE_IMAGES" == "1" ]]; then
  log "Bundling container images"
  bundle_images
else
  warn "Images are not included. Set INCLUDE_IMAGES=1 to bundle them (requires docker)."
fi

tar_name="offline-package-gitlab-${ARCH}.tar.gz"
rm -f "$tar_name"
log "Creating archive ${tar_name}"
tar -czpf "$tar_name" "$WORKDIR"
log "Done"
