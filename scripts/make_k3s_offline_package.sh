#!/usr/bin/env bash
# scripts/make_k3s_offline_package.sh
# 构建离线安装包：输出到仓库根目录 k3s-offline-package-${ARCH}.tar.gz
# 依赖：curl、tar、（优先）docker 或（备选）containerd+nerdctl
set -euo pipefail

# ====== 参数与默认值 ======
VERSION="${VERSION:-${K3S_VERSION:-v1.33.4+k3s1}}"
ARCH="${ARCH:-amd64}"                       # 由 matrix 传入：amd64/arm64
BASE_DIR="${BASE_DIR:-k3s-offline-package}"
CNI_VERSION="${CNI_VERSION:-v1.3.0}"
HELM_VERSION="${HELM_VERSION:-v3.14.2}"
NERDCTL_VERSION="${NERDCTL_VERSION:-2.1.4}"

# kubectl 版本：默认给一个常用稳定版；可通过 KUBECTL_VERSION 覆盖
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.30.0}"

# URL
K3S_URL_BASE="https://github.com/k3s-io/k3s/releases/download/${VERSION}"

# ====== 工具函数 ======
log() { echo -e "[\e[32mINFO\e[0m] $*"; }
err() { echo -e "[\e[31mERROR\e[0m] $*" >&2; exit 1; }

download() {
  local url="$1" out="$2"
  if [[ -f "$out" ]]; then
    log "SKIP 已存在：$out"
    return
  fi
  log "DOWNLOAD $url -> $out"
  curl -fSL --retry 3 --retry-connrefused --connect-timeout 15 "$url" -o "$out"
  [[ -s "$out" ]] || err "空文件：$out"
}

pick_runtime() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "docker"; return
  fi
  if command -v nerdctl >/dev/null 2>&1 && [[ -S /run/containerd/containerd.sock ]]; then
    echo "nerdctl-default"; return
  fi
  echo "none"
}

pull_and_save_images() {
  local out_tar="$1"
  local imgs=(
    docker.io/rancher/mirrored-pause:3.6
    docker.io/rancher/mirrored-metrics-server:v0.6.3
    docker.io/rancher/mirrored-coredns-coredns:1.10.1
    docker.io/rancher/mirrored-prometheus-node-exporter:v1.3.1
    docker.io/rancher/mirrored-kube-state-metrics-kube-state-metrics:v2.12.0
  )

  local rt; rt="$(pick_runtime)"
  [[ "$rt" != "none" ]] || err "未找到可用镜像运行时（docker 或 containerd+nerdctl）"

  log "拉取核心镜像（runtime=$rt）…"
  case "$rt" in
    docker)
      for i in "${imgs[@]}"; do
        docker rmi -f "$i" >/dev/null 2>&1 || true
        docker pull --platform=linux/${ARCH} "$i"
        local arch
        arch=$(docker image inspect "$i" --format '{{.Architecture}}')
        [[ "$arch" == "$ARCH" ]] || err "镜像 $i 架构不匹配：$arch"
      done
      log "保存镜像 → $out_tar"
      docker save -o "$out_tar" "${imgs[@]}"
      ;;
    nerdctl-default)
      for i in "${imgs[@]}"; do sudo nerdctl --address /run/containerd/containerd.sock --platform=linux/${ARCH} pull "$i"; done
      log "保存镜像 → $out_tar"
      sudo nerdctl --address /run/containerd/containerd.sock --platform=linux/${ARCH} save -o "$out_tar" "${imgs[@]}"
      ;;
  esac
  [[ -s "$out_tar" ]] || err "未生成镜像包：$out_tar"

  if command -v jq >/dev/null 2>&1; then
    local tmp cfg arch_in_tar
    tmp=$(mktemp -d)
    tar -xf "$out_tar" -C "$tmp" manifest.json
    for cfg in $(jq -r '.[].Config' "$tmp/manifest.json"); do
      tar -xf "$out_tar" -C "$tmp" "$cfg"
      arch_in_tar=$(jq -r '.architecture' "$tmp/$cfg")
      [[ "$arch_in_tar" == "$ARCH" ]] || err "镜像包架构不匹配：$arch_in_tar"
    done
    rm -rf "$tmp"
  else
    log "jq 未安装，跳过镜像包架构校验"
  fi
}

write_node_exporter_yaml() {
  cat > "${BASE_DIR}/addons/node-exporter.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata: {name: node-exporter, namespace: kube-system}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: node-exporter}
rules:
- apiGroups: [""]
  resources: ["nodes","nodes/proxy","services","endpoints"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: node-exporter}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: node-exporter}
subjects:
- kind: ServiceAccount
  name: node-exporter
  namespace: kube-system
---
apiVersion: apps/v1
kind: DaemonSet
metadata: {name: node-exporter, namespace: kube-system}
spec:
  selector: {matchLabels: {app: node-exporter}}
  template:
    metadata: {labels: {app: node-exporter}}
    spec:
      hostPID: true
      hostNetwork: true
      serviceAccountName: node-exporter
      containers:
      - name: node-exporter
        image: docker.io/rancher/mirrored-prometheus-node-exporter:v1.3.1
        imagePullPolicy: IfNotPresent
        args: ["--path.procfs=/host/proc","--path.sysfs=/host/sys","--path.rootfs=/host/root"]
        securityContext: {privileged: true}
        resources: {requests: {cpu: "50m", memory: "30Mi"}}
        volumeMounts:
        - {name: proc,   mountPath: /host/proc,  readOnly: true}
        - {name: sys,    mountPath: /host/sys,   readOnly: true}
        - {name: rootfs, mountPath: /host/root,  readOnly: true}
      volumes:
      - {name: proc,   hostPath: {path: /proc}}
      - {name: sys,    hostPath: {path: /sys}}
      - {name: rootfs, hostPath: {path: /}}
---
apiVersion: v1
kind: Service
metadata: {name: node-exporter, namespace: kube-system, labels: {app: node-exporter}}
spec:
  clusterIP: None
  selector: {app: node-exporter}
  ports: [{name: metrics, port: 9100, targetPort: 9100}]
YAML
}

write_ksm_yaml() {
  cat > "${BASE_DIR}/addons/kube-state-metrics.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata: {name: kube-state-metrics, namespace: kube-system}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: kube-state-metrics}
rules:
- apiGroups: [""]
  resources: ["pods","nodes","namespaces","services","endpoints","persistentvolumes","persistentvolumeclaims","configmaps","secrets","limitranges","replicationcontrollers"]
  verbs: ["get","list","watch"]
- apiGroups: ["apps"]
  resources: ["statefulsets","daemonsets","deployments","replicasets"]
  verbs: ["get","list","watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs","jobs"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: kube-state-metrics}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: kube-state-metrics}
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: kube-state-metrics, namespace: kube-system}
spec:
  replicas: 1
  selector: {matchLabels: {app: kube-state-metrics}}
  template:
    metadata: {labels: {app: kube-state-metrics}}
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: docker.io/rancher/mirrored-kube-state-metrics-kube-state-metrics:v2.12.0
        imagePullPolicy: IfNotPresent
        ports:
        - {name: metrics,   containerPort: 8080}
        - {name: telemetry, containerPort: 8081}
        resources: {requests: {cpu: "40m", memory: "60Mi"}}
---
apiVersion: v1
kind: Service
metadata: {name: kube-state-metrics, namespace: kube-system, labels: {app: kube-state-metrics}}
spec:
  selector: {app: kube-state-metrics}
  ports:
  - {name: metrics,   port: 8080, targetPort: 8080}
  - {name: telemetry, port: 8081, targetPort: 8081}
YAML
}

write_install_server() {
  cat > "${BASE_DIR}/install-server.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
ARCH=$(uname -m)
case "$ARCH" in x86_64|amd64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) echo "Unsupported arch: $ARCH"; exit 1;; esac

BIN_DIR="./bin"
install_bin(){ sudo cp "$1" "$2"; sudo chmod +x "$2"; echo " ↳ $2"; }
check_images(){
  echo "[INFO] 验证已加载镜像架构"
  local out
  out=$(sudo nerdctl --namespace k8s.io --address /run/k3s/containerd/containerd.sock images -a --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Platform}}')
  echo "$out"
  if echo "$out" | awk '{print $3}' | grep -v "linux/${ARCH}" >/dev/null; then
    echo "[ERROR] 发现非 ${ARCH} 架构镜像" >&2
    exit 1
  fi
}

echo "[INFO] 安装 CLI → /usr/local/bin"
install_bin "${BIN_DIR}/k3s-${ARCH}" /usr/local/bin/k3s
install_bin "${BIN_DIR}/helm-${ARCH}" /usr/local/bin/helm
install_bin "${BIN_DIR}/kubectl-${ARCH}" /usr/local/bin/kubectl
install_bin "${BIN_DIR}/nerdctl-${ARCH}" /usr/local/bin/nerdctl

echo "[INFO] 执行官方离线安装脚本"
INSTALL_K3S_SKIP_DOWNLOAD=true \
INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644 --disable=traefik,servicelb,local-storage --kube-apiserver-arg=service-node-port-range=0-50000" \
bash "install/k3s-official-install.sh"

echo "[INFO] 加载 airgap 镜像"
sudo nerdctl --namespace k8s.io --address /run/k3s/containerd/containerd.sock load -i "images/k3s-airgap-images-${ARCH}.tar" || true

echo "[INFO] 应用默认组件（若失败可忽略）"
mkdir -p ~/.kube && cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config || true
kubectl apply -f addons/node-exporter.yaml || true
kubectl apply -f addons/kube-state-metrics.yaml || true

check_images

echo "[SUCCESS] 离线 K3s 安装完成 ✅"
SH
  chmod +x "${BASE_DIR}/install-server.sh"
}

write_install_agent() {
  cat > "${BASE_DIR}/install-agent.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
ARCH=$(uname -m)
case "$ARCH" in x86_64|amd64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) echo "Unsupported arch: $ARCH"; exit 1;; esac
[[ -n "${K3S_TOKEN:-}" && -n "${K3S_URL:-}" ]] || { echo "[ERROR] 需要设置 K3S_TOKEN 与 K3S_URL"; exit 1; }

BIN_DIR="./bin"
install_bin(){ sudo cp "$1" "$2"; sudo chmod +x "$2"; echo " ↳ $2"; }
check_images(){
  echo "[INFO] 验证已加载镜像架构"
  local out
  out=$(sudo nerdctl --namespace k8s.io --address /run/k3s/containerd/containerd.sock images -a --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Platform}}')
  echo "$out"
  if echo "$out" | awk '{print $3}' | grep -v "linux/${ARCH}" >/dev/null; then
    echo "[ERROR] 发现非 ${ARCH} 架构镜像" >&2
    exit 1
  fi
}

echo "[INFO] 安装 CLI → /usr/local/bin"
install_bin "${BIN_DIR}/k3s-${ARCH}" /usr/local/bin/k3s
install_bin "${BIN_DIR}/nerdctl-${ARCH}" /usr/local/bin/nerdctl

echo "[INFO] 执行官方 agent 安装脚本（离线）"
INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC="agent" bash install/k3s-official-install.sh

echo "[INFO] 加载 airgap 镜像"
sudo nerdctl --namespace k8s.io --address /run/k3s/containerd/containerd.sock load -i "images/k3s-airgap-images-${ARCH}.tar" || true

check_images

echo "[SUCCESS] Agent 节点离线安装完成 ✅"
SH
  chmod +x "${BASE_DIR}/install-agent.sh"
}

write_readme() {
  cat > "${BASE_DIR}/README.md" <<EOF
# K3s 离线安装包（${VERSION}，支持 ${ARCH}）

包含：
- k3s (${VERSION})
- kubectl (${KUBECTL_VERSION})
- helm (${HELM_VERSION})
- cni-plugins (${CNI_VERSION})
- nerdctl (${NERDCTL_VERSION})
- airgap 镜像包 \`images/k3s-airgap-images-${ARCH}.tar\`
- 默认组件 YAML：node-exporter / kube-state-metrics
- 安装脚本：install-server.sh / install-agent.sh

## 使用
\`\`\`bash
tar -xzvf k3s-offline-package-${ARCH}.tar.gz
cd k3s-offline-package
bash install-server.sh
# 或者：
export K3S_URL=https://<server-ip>:6443
export K3S_TOKEN=K10xxxxxxxx
bash install-agent.sh
\`\`\`
EOF
}

# ====== 构建开始 ======
log "版本：k3s=${VERSION} kubectl=${KUBECTL_VERSION} helm=${HELM_VERSION} cni=${CNI_VERSION} nerdctl=${NERDCTL_VERSION} arch=${ARCH}"

rm -rf "${BASE_DIR}"
mkdir -p "${BASE_DIR}/"{bin,images,cni-plugins,addons,registry/docker.io,registry/ghcr.io,install}

# 核心二进制
K3S_BIN="k3s"
if [[ "${ARCH}" != "amd64" ]]; then
  K3S_BIN="k3s-${ARCH}"
fi
download "${K3S_URL_BASE}/${K3S_BIN}"                "${BASE_DIR}/bin/k3s-${ARCH}"
chmod +x "${BASE_DIR}/bin/k3s-${ARCH}"

download "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" "${BASE_DIR}/bin/kubectl-${ARCH}"
chmod +x "${BASE_DIR}/bin/kubectl-${ARCH}"

TMP_HELM="/tmp/helm-${HELM_VERSION}-${ARCH}.tgz"
download "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" "$TMP_HELM"
tar -xzf "$TMP_HELM" -C /tmp
mv "/tmp/linux-${ARCH}/helm" "${BASE_DIR}/bin/helm-${ARCH}"
chmod +x "${BASE_DIR}/bin/helm-${ARCH}"

TMP_NERD="/tmp/nerdctl-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz"
download "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz" "$TMP_NERD"
tar -xzf "$TMP_NERD" -C /tmp
cp "/tmp/nerdctl" "${BASE_DIR}/bin/nerdctl-${ARCH}"
chmod +x "${BASE_DIR}/bin/nerdctl-${ARCH}"

download "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" \
         "${BASE_DIR}/cni-plugins/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz"

# 安装器脚本
download "https://get.k3s.io" "${BASE_DIR}/install/k3s-official-install.sh"
chmod +x "${BASE_DIR}/install/k3s-official-install.sh"

# YAML 与镜像
write_node_exporter_yaml
write_ksm_yaml
pull_and_save_images "${BASE_DIR}/images/k3s-airgap-images-${ARCH}.tar"

# 友好文档与执行脚本
write_install_server
write_install_agent
write_readme

# 打包（与流水线期望名称一致）
OUT_A="k3s-offline-package-${ARCH}.tar.gz"
log "打包 → ${OUT_A}"
tar -czf "${OUT_A}" "${BASE_DIR}"

# 兼容 build Job 当前上传的名称（内容相同）
OUT_B="offline-package-k3s-installer.tar.gz"
cp -f "${OUT_A}" "${OUT_B}"
log "同时生成（兼容名）→ ${OUT_B}"

# 列目录
log "构建完成"
tar -tzf "${OUT_A}" >/dev/null
tree "${BASE_DIR}" || true
