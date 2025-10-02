#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-}"
if [[ -z "${ARCH}" ]]; then
  echo "ARCH environment variable is required" >&2
  exit 1
fi

WORKDIR="terraform-offline-package"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}/"{bin,scripts,docs}

BASE_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
ARCHIVE="terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip"
echo "Downloading ${BASE_URL}/${ARCHIVE}"
curl -fSL "${BASE_URL}/${ARCHIVE}" -o "${ARCHIVE}"

unzip -d "${WORKDIR}/bin" "${ARCHIVE}"
rm -f "${ARCHIVE}"

echo "${TERRAFORM_VERSION}" > "${WORKDIR}/VERSION"

cat <<'SCRIPT' > "${WORKDIR}/scripts/install-terraform.sh"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT_DIR}/bin/terraform"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--install]
  --install    Copy terraform binary into ${INSTALL_DIR}
USAGE
}

if [[ "${1:-}" == "--install" ]]; then
  sudo install -m 0755 "$BIN" "${INSTALL_DIR}/terraform"
  echo "Terraform installed to ${INSTALL_DIR}/terraform"
else
  usage
fi
SCRIPT
chmod +x "${WORKDIR}/scripts/install-terraform.sh"

tar -czf "terraform-offline-package-${ARCH}.tar.gz" "${WORKDIR}"
ls -lh "terraform-offline-package-${ARCH}.tar.gz"
