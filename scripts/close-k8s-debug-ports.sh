#!/bin/bash

# Close insecure debug ports for kube-scheduler and kube-controller-manager

set -euo pipefail

echo "🔧 Closing 10251 and 10252 debug ports..."

for file in /etc/kubernetes/manifests/kube-scheduler.yaml \
            /etc/kubernetes/manifests/kube-controller-manager.yaml; do
  if grep -q -- '--port=' "$file"; then
    sed -i 's/--port=[0-9]\+/--port=0/' "$file"
  else
    sed -i '/command:/a \    - --port=0' "$file"
  fi
done

echo "✅ Done. kubelet will reload pods in 10 seconds."
