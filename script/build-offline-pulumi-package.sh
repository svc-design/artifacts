#!/usr/bin/env bash
set -euo pipefail

ARCH="${MATRIX_ARCH:-}"
if [[ -z "${ARCH}" ]]; then
  echo "MATRIX_ARCH environment variable is required" >&2
  exit 1
fi

case "${ARCH}" in
  amd64) ASSET_ARCH="x64" ;;
  arm64) ASSET_ARCH="arm64" ;;
  *)
    echo "Unsupported arch: ${ARCH}" >&2
    exit 1
    ;;
esac

WORKDIR="pulumi-offline-package"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}" "${WORKDIR}/scripts"

ARCHIVE="pulumi-v${PULUMI_VERSION}-linux-${ASSET_ARCH}.tar.gz"
URL="https://get.pulumi.com/releases/sdk/${ARCHIVE}"
echo "Downloading ${URL}"
curl -fSL "${URL}" -o "${ARCHIVE}"

tar -xzvf "${ARCHIVE}" -C "${WORKDIR}" --strip-components=1
rm -f "${ARCHIVE}"

echo "${PULUMI_VERSION}" > "${WORKDIR}/VERSION"

cat <<'SCRIPT' > "${WORKDIR}/scripts/install-pulumi.sh"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/bin"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

if [[ "${1:-}" == "--install" ]]; then
  sudo install -m 0755 "${BIN_DIR}"/* "${INSTALL_DIR}/"
  echo "Pulumi binaries installed to ${INSTALL_DIR}"
else
  cat <<USAGE
Usage: $(basename "$0") --install
  --install    Copy Pulumi CLI binaries into ${INSTALL_DIR}
USAGE
fi
SCRIPT
chmod +x "${WORKDIR}/scripts/install-pulumi.sh"

OUTPUT_ARCHIVE="offline-package-pulumi-${ARCH}.tar.gz"
tar -czf "${OUTPUT_ARCHIVE}" "${WORKDIR}"
ls -lh "${OUTPUT_ARCHIVE}"
