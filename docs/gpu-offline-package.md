# 构建 GPU Kubernetes 离线包

本仓库提供 `scripts/create-gpu-k8s-offline-package.sh` 脚本，用于生成在无网络环境下部署 GPU 集群所需的离线文件。脚本默认打包 Kubernetes 以及相关组件的 `v1.29.9` 版本，你可以通过环境变量调整需要的版本。

## 使用方法

```bash
# 构建默认版本 (v1.29.9)
bash scripts/create-gpu-k8s-offline-package.sh

# 指定其它版本，例如 v1.28.7
K8S_VERSION=labring/kubernetes:v1.28.7 \
bash scripts/create-gpu-k8s-offline-package.sh
```

生成的 `gpu_k8s_offline_packages.tar.gz` 包含以下内容：

- Kubernetes 二进制镜像
- Cilium、Helm 等依赖镜像
- NVIDIA 驱动（nvidia-driver-535）及 nvidia-container-toolkit 离线包（deb/rpm）
- nerdctl CLI（v${NERDCTL_VERSION:-2.1.2}）
- 必要的容器镜像，包括 `registry.k8s.io/pause:3.8`
- GPU 环境检测脚本 `check-gpu-status.sh`

该离线包用于基于 `sealos` 部署 Kubernetes，最低推荐版本为 **1.29**，也可以使用更新的 `1.30` 等稳定版本。

