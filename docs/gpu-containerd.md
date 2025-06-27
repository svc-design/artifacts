# 在 Ubuntu 上安装 NVIDIA 驱动和 nvidia-container-toolkit

以下步骤演示如何在主机安装 NVIDIA 驱动及 nvidia-container-toolkit，并将 containerd 配置为能够使用 GPU。末尾还补充了 sealos 自带 containerd 的配置方式。

## 1. 安装 NVIDIA 驱动和 nvidia-container-toolkit

```bash
# 添加 NVIDIA 容器工具箱仓库
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

distribution=$(awk -F= '/^ID=/{print $2}' /etc/os-release)$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release)
curl -s -L "https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list" | \
  sed 's#^deb #deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] #' | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-driver-535 nvidia-container-toolkit
```

安装完成后可通过 `nvidia-smi` 验证驱动是否正常：

```bash
nvidia-smi
```

## 2. 配置 containerd 使用 GPU

使用 `nvidia-ctk` 工具可以快速生成配置并设置为默认运行时：

```bash
sudo nvidia-ctk runtime configure --runtime=containerd --set-as-default
sudo systemctl restart containerd
```

以上命令会在 `/etc/containerd/config.toml` 中新增 `nvidia` 运行时，使 kubelet 或其他工具可以直接调度 GPU 容器。

## 3. sealos-containerd 支持

若主机通过 [sealos](https://github.com/labring/sealos) 部署集群，其内置的 containerd 服务名通常为 `sealos-containerd`，配置文件位于 sealos 数据目录，例如：
`/var/lib/sealos/data/default/rootfs/etc/containerd/config.toml`。可按以下方式配置：

```bash
sudo nvidia-ctk runtime configure \
  --config /var/lib/sealos/data/default/rootfs/etc/containerd/config.toml \
  --set-as-default
sudo systemctl restart sealos-containerd
```

完成后即可在 sealos 集群内运行需要 GPU 的容器或 Pod。
