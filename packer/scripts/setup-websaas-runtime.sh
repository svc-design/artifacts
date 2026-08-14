#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Setting up Web SaaS Production Runtime Node"
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
  iptables \
  ufw

# Ensure DNS remains valid after package installation
if ! grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# 2. Configure Docker Repository & Install Production Docker Runtime
# (Notice: Excludes developer plugins like docker-buildx-plugin)
install -m 0755 -d /etc/apt/keyrings
DISTRO_NAME="$(lsb_release -is | tr '[:upper:]' '[:lower:]')"
CODENAME="$(lsb_release -cs)"

# Fallback for Debian testing / non-standard codenames
if [ "$DISTRO_NAME" = "debian" ] && [ "$CODENAME" = "n/a" -o "$CODENAME" = "trixie" ]; then
  CODENAME="bookworm"
fi

curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused "https://download.docker.com/linux/${DISTRO_NAME}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_NAME} ${CODENAME} stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

systemctl enable docker

# 3. Configure Caddy Official Repository & Install Caddy
curl -1sLf --retry 5 --retry-delay 2 --retry-connrefused 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf --retry 5 --retry-delay 2 --retry-connrefused 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

apt-get update -y
apt-get install -y --no-install-recommends caddy || echo "Caddy fallback to standard apt if available"

if command -v caddy &>/dev/null; then
  systemctl enable caddy
fi

# 4. Create Web SaaS directories
mkdir -p /opt/web-saas /etc/caddy /var/log/caddy /var/www/html
chmod 755 /opt/web-saas /etc/caddy

# 5. Kernel / Network Tuning for Production Web Runtime
cat <<'EOF' > /etc/sysctl.d/99-websaas-runtime.conf
net.ipv4.ip_forward = 1
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
EOF

sysctl --system || true

# 6. Pre-install Observability Agents (Vector & Node Exporter)
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

echo "Web SaaS Production Runtime Setup Completed Successfully."
