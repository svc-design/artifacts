#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Setting up Web SaaS Production Runtime Node"
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
  iptables \
  ufw \
  systemd-resolved

# 2. Configure Docker Repository & Install Production Docker Runtime
# (Notice: Excludes developer plugins like docker-buildx-plugin)
install -m 0755 -d /etc/apt/keyrings
DISTRO_NAME="$(lsb_release -is | tr '[:upper:]' '[:lower:]')"
CODENAME="$(lsb_release -cs)"

# Fallback for Debian testing / non-standard codenames
if [ "$DISTRO_NAME" = "debian" ] && [ "$CODENAME" = "n/a" -o "$CODENAME" = "trixie" ]; then
  CODENAME="bookworm"
fi

curl -fsSL "https://download.docker.com/linux/${DISTRO_NAME}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
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
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

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

echo "Web SaaS Production Runtime Setup Completed Successfully."
