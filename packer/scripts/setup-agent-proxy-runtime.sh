#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Setting up Agent Proxy Production Runtime Node"
echo "======================================================="

export DEBIAN_FRONTEND=noninteractive

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
  stunnel4 \
  systemd-resolved

# 2. Pre-create directories for Agent Proxy & Xray
mkdir -p /etc/agent-proxy /var/log/agent-proxy /etc/xray /var/log/xray /etc/stunnel
chmod 755 /etc/agent-proxy /etc/xray /etc/stunnel

# 3. Install Xray-core Binary (Production Runtime)
XRAY_VERSION="v25.1.30"
XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"

echo "Downloading Xray-core ${XRAY_VERSION}..."
TEMP_DIR="$(mktemp -d)"
if curl -fsSL "${XRAY_URL}" -o "${TEMP_DIR}/xray.zip"; then
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

echo "Agent Proxy Production Runtime Setup Completed Successfully."
