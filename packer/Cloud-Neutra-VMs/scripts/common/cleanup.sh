#!/usr/bin/env bash
set -euo pipefail

echo "[Cloud-Neutra] Cleanup phase"

sudo apt-get autoremove -y
sudo apt-get clean -y
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /tmp/* /var/tmp/*

# Cloud images best practice
sudo truncate -s 0 /var/log/wtmp || true
sudo truncate -s 0 /var/log/lastlog || true

echo "[Cloud-Neutra] Cleanup complete."
