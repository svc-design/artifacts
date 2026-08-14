#!/usr/bin/env bash
set -euo pipefail

# Pre-install the binaries used by playbooks/deploy_observability_agent.yml.
# Configuration, credentials, and service activation remain deployment-time
# concerns; the Golden Image only carries immutable runtime artifacts.

export DEBIAN_FRONTEND=noninteractive

ARCH_NAME="$(dpkg --print-architecture)"
case "${ARCH_NAME}" in
  amd64|arm64) ;;
  *)
    echo "Unsupported Debian architecture: ${ARCH_NAME}" >&2
    exit 1
    ;;
esac

METRICS_DIR=/opt/metrics-agent
mkdir -p "${METRICS_DIR}"

VECTOR_VERSION="0.41.1"
NODE_EXPORTER_VERSION="1.8.2"
PROCESS_EXPORTER_VERSION="0.7.10"
POSTGRES_EXPORTER_VERSION="0.19.1"

TEMP_OBS_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_OBS_DIR}"' EXIT

echo "Pre-installing observability runtime for ${ARCH_NAME}..."

# Vector is installed from the same package used by the Vector Ansible role.
VECTOR_DEB_URL="https://github.com/vectordotdev/vector/releases/download/v${VECTOR_VERSION}/vector_${VECTOR_VERSION}-1_${ARCH_NAME}.deb"
if ! command -v vector >/dev/null 2>&1; then
  curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused \
    "${VECTOR_DEB_URL}" -o "${TEMP_OBS_DIR}/vector.deb"
  apt-get install -y "${TEMP_OBS_DIR}/vector.deb"
fi

install -m 0755 -d /etc/vector
systemctl enable vector || true

# Match roles/vhosts/node_exporter exactly so a later convergence only needs
# to render configuration and restart the service instead of downloading it.
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_NAME}.tar.gz"
if [[ ! -x "${METRICS_DIR}/node_exporter" ]]; then
  curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused \
    "${NODE_EXPORTER_URL}" | tar -xz -C "${TEMP_OBS_DIR}"
  install -m 0755 \
    "${TEMP_OBS_DIR}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_NAME}/node_exporter" \
    "${METRICS_DIR}/node_exporter"
fi

install -d -o nobody -g nogroup -m 0755 /var/lib/node_exporter
cat > /etc/systemd/system/node-exporter.service <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
Group=nogroup
ExecStart=/opt/metrics-agent/node_exporter --web.listen-address=127.0.0.1:9100 --collector.textfile --collector.textfile.directory=/var/lib/node_exporter
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Process exporter is intentionally installed but not started: its config is
# deployment-specific and is rendered by the Ansible role.
if [[ ! -x /usr/local/bin/process-exporter ]]; then
  PROCESS_EXPORTER_URL="https://github.com/ncabatoff/process-exporter/releases/download/v${PROCESS_EXPORTER_VERSION}/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-${ARCH_NAME}.tar.gz"
  curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused \
    "${PROCESS_EXPORTER_URL}" | tar -xz -C "${TEMP_OBS_DIR}"
  install -m 0755 \
    "${TEMP_OBS_DIR}/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-${ARCH_NAME}/process-exporter" \
    /usr/local/bin/process-exporter
fi

if ! getent group process_exporter >/dev/null 2>&1; then
  groupadd --system process_exporter
fi
if ! id process_exporter >/dev/null 2>&1; then
  useradd --system --gid process_exporter --shell /usr/sbin/nologin --no-create-home process_exporter
fi
cat > /etc/systemd/system/process-exporter.service <<'EOF'
[Unit]
Description=process-exporter
Wants=network-online.target
After=network-online.target

[Service]
User=process_exporter
Group=process_exporter
ExecStart=/usr/local/bin/process-exporter --config.path /etc/process-exporter.yml --web.listen-address=127.0.0.1:9256
Restart=always
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

install -m 0755 -o process_exporter -g process_exporter /dev/null /etc/process-exporter.yml

# PostgreSQL exporter is only needed on the Web SaaS image. It is never
# started here because its connection credentials are environment-specific.
if [[ "${INSTALL_POSTGRES_EXPORTER:-0}" == "1" ]]; then
  case "${ARCH_NAME}" in
    amd64) POSTGRES_EXPORTER_SHA256="229096c7988df6ca41fe5b4bf66865089971535e7f0d819c12c920ec64dd2bd0" ;;
    arm64) POSTGRES_EXPORTER_SHA256="0ac6fe8c1f66f13b12adb8da282d248d9e1a48df6684e453ca232fd8fd62a11a" ;;
  esac
  POSTGRES_EXPORTER_URL="https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-${ARCH_NAME}.tar.gz"
  POSTGRES_EXPORTER_ARCHIVE="${TEMP_OBS_DIR}/postgres_exporter.tar.gz"
  curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused \
    "${POSTGRES_EXPORTER_URL}" -o "${POSTGRES_EXPORTER_ARCHIVE}"
  printf '%s  %s\n' "${POSTGRES_EXPORTER_SHA256}" "${POSTGRES_EXPORTER_ARCHIVE}" | sha256sum -c -
  tar -xzf "${POSTGRES_EXPORTER_ARCHIVE}" -C "${TEMP_OBS_DIR}"
  install -m 0755 \
    "${TEMP_OBS_DIR}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-${ARCH_NAME}/postgres_exporter" \
    "${METRICS_DIR}/postgres_exporter"
fi

systemctl daemon-reload || true
systemctl enable node-exporter || true
echo "Observability runtime pre-install completed successfully."
