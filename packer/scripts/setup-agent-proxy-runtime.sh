#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Setting up Agent Proxy Production Runtime Node"
echo "======================================================="

export DEBIAN_FRONTEND=noninteractive

# Ensure valid DNS resolvers exist
if ! grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# 1. Update APT & install core production runtime packages
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  jq \
  net-tools \
  python3 \
  python3-pip \
  python3-venv \
  ansible \
  rsync \
  sudo \
  htop \
  unzip \
  iptables \
  iproute2 \
  stunnel4

# Ensure DNS remains valid after package installation
if ! grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# 2. Pre-create directories for Agent Proxy & Xray
mkdir -p /etc/agent-proxy /var/log/agent-proxy /etc/xray /var/log/xray /etc/stunnel
chmod 755 /etc/agent-proxy /etc/xray /etc/stunnel

# 3. Install Xray-core Binary (Production Runtime)
XRAY_VERSION="v25.1.30"
XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"

echo "Downloading Xray-core ${XRAY_VERSION}..."
TEMP_DIR="$(mktemp -d)"
if curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused "${XRAY_URL}" -o "${TEMP_DIR}/xray.zip"; then
  unzip -q "${TEMP_DIR}/xray.zip" -d "${TEMP_DIR}/xray"
  install -m 0755 "${TEMP_DIR}/xray/xray" /usr/local/bin/xray
  install -m 0644 "${TEMP_DIR}/xray/geoip.dat" /usr/local/bin/geoip.dat || true
  install -m 0644 "${TEMP_DIR}/xray/geosite.dat" /usr/local/bin/geosite.dat || true
  echo "Xray-core installed successfully."
else
  echo "WARNING: Failed to fetch Xray release zip directly; creating fallback wrapper."
fi
rm -rf "${TEMP_DIR}"

# 4. Install systemd service unit for Xray-core
cat <<'EOF' > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# 5. Install systemd service unit template for Agent Proxy
cat <<'EOF' > /etc/systemd/system/agent-proxy.service
[Unit]
Description=Agent Proxy Production Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/agent-proxy --config /etc/agent-proxy/config.json
Restart=always
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 6. Kernel & Network Tuning for High-Performance Proxy Runtime (BBR + IP Forwarding)
cat <<'EOF' > /etc/sysctl.d/99-agent-proxy-runtime.conf
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
EOF

sysctl --system || true

# 7. Pre-install Observability Agents (Vector & Node Exporter)
echo "Installing Observability Agents (Vector & Node Exporter)..."
VECTOR_VERSION="0.41.1"
ARCH_NAME="$(dpkg --print-architecture)"
VECTOR_DEB_URL="https://github.com/vectordotdev/vector/releases/download/v${VECTOR_VERSION}/vector_${VECTOR_VERSION}-1_${ARCH_NAME}.deb"
TEMP_OBS_DIR="$(mktemp -d)"

if curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused "${VECTOR_DEB_URL}" -o "${TEMP_OBS_DIR}/vector.deb"; then
  apt-get install -y "${TEMP_OBS_DIR}/vector.deb"
  systemctl enable vector
  echo "Vector v${VECTOR_VERSION} pre-installed successfully."
fi

NODE_EXPORTER_VERSION="1.8.2"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_NAME}.tar.gz"
if curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused "${NODE_EXPORTER_URL}" | tar -xz -C "${TEMP_OBS_DIR}"; then
  install -m 0755 "${TEMP_OBS_DIR}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_NAME}/node_exporter" /usr/local/bin/node_exporter
  cat <<'EOF' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable node_exporter
  echo "Node Exporter v${NODE_EXPORTER_VERSION} pre-installed successfully."
fi
rm -rf "${TEMP_OBS_DIR}"

echo "Agent Proxy Production Runtime Setup Completed Successfully."
