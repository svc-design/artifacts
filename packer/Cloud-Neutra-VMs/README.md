# Cloud-Neutra Golden Image Pipeline

Cloud-Neutra Golden Image Pipeline 为多云环境构建一套统一、可靠、可自动化的 Ubuntu Golden Image 家族。
该体系覆盖 Ubuntu LTS 双版本（22.04 / 24.04）、双架构（amd64 / arm64） 以及多个容器/集群运行时的变种。

Pipeline 包含：
- Packer 自动构建 AMI
- GitHub Actions 全自动流水线（构建 → 多 Region 复制 → 过期清理）
- Terraform 模块自动引用最新 Golden Image
- 完全统一的脚本与硬化规范

## 0. Overall Goals

Ubuntu LTS Baseline

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

CPU Architectures

- amd64
- arm64

### Golden Image Editions

- Edition	内容说明
- base	干净操作系统 + 基础硬化（去 snap，去 MOTD，去不必要服务）
- container	containerd + nerdctl，作为通用 Container VM
- k3s	预装 K3s，可在运行时决定 server/agent
- sealos	预装 sealos CLI + containerd
- sealos-gpu	适用于 GPU 节点：sealos + NVIDIA 驱动 + nvidia-container-toolkit

###  Pipeline 统一要求

- 完整统一脚本结构（base → flavor）
- 去除 snap / MOTD / landscape / update-notifier 等非必要组件
- 无 amazon-import 误用（使用 amazon-ebs 构建 AMI）

GitHub Actions 统一构建 + 多 Region 复制

- 每 Edition / Version / Arch 每月仅保留 1 个 AMI
- Terraform 自动检索“最新且合法”的 Golden Image

## 1. Naming Conventions & Tagging

### AMI 命名规范

Cloud-Neutra-${edition}-VM-${ubuntu_version}-${arch}-${timestamp}

示例：

- Cloud-Neutra-base-VM-2204-amd64-20251121-120000
- Cloud-Neutra-container-VM-2404-arm64-20251121-123000
- Cloud-Neutra-k3s-VM-2404-amd64-20251121-130000
- Cloud-Neutra-sealos-gpu-VM-2404-amd64-20251121-133000

### 统一标签（Tags）

- Key	Value
- Project	Cloud-Neutra
- OS	Ubuntu 22.04 / Ubuntu 24.04
- Edition	base / container / k3s / sealos / sealos-gpu
- Architecture	amd64 / arm64
- Role	Golden-Image

这些标签用于：

GitHub Actions Retention 策略过滤

Terraform AMI 检索
多 Region 管理
生产审计与溯源

## 2 . Directory Layout

```
packer/
  templates/
    base/
      ubuntu-2204-base.pkr.hcl
      ubuntu-2404-base.pkr.hcl
    container/
      ubuntu-2204-container.pkr.hcl
      ubuntu-2404-container.pkr.hcl
    k3s/
      ubuntu-2204-k3s.pkr.hcl
      ubuntu-2404-k3s.pkr.hcl
    sealos/
      ubuntu-2204-sealos.pkr.hcl
      ubuntu-2404-sealos.pkr.hcl
    sealos-gpu/
      ubuntu-2204-sealos-gpu.pkr.hcl
      ubuntu-2404-sealos-gpu.pkr.hcl

  scripts/
    base/
      01_os_base.sh          # 开源仓库、更新系统、移除 snap / motd 等
      02_hardening.sh        # 可选：sysctl / sshd / journald 硬化
    flavors/
      container.sh
      k3s.sh
      sealos.sh
      sealos_gpu.sh
    common/
      cleanup.sh             # apt autoremove + 清理临时文件
```

模板结构说明

- 每个 flavor 模板只负责：
- 指定 Ubuntu 版本与 CPU 架构
- 引用 base 脚本（01_os_base.sh / 02_hardening.sh）
- 引用 flavor 脚本（如 container.sh / k3s.sh）
- 最后引用 cleanup.sh

## 3. Script Architecture

Base Scripts (scripts/base/)

### 01_os_base.sh

启用 universe/multiverse
dist-upgrade（禁内核升级风险）
移除 snapd / resolvconf / landscape / MOTD-news
安装基础工具：curl、jq、lsb-release、net-tools、iptables
关闭 apt-daily 自动更新

### 02_hardening.sh

可选的系统硬化（sysctl、sshd、journald 持久化等）
Flavor Scripts (scripts/flavors/)
container.sh
containerd + nerdctl 安装
containerd config 自动生成
k3s.sh 安装 K3s（skip-start） 运行时可作为 server 或 agent
sealos.sh 安装 sealos CLI 依赖 containerd（可复用 container flavor）
sealos_gpu.sh 安装 NVIDIA 驱动（可扩展到不同云平台） 安装 nvidia-container-toolkit

安装 sealos

Common Scripts (scripts/common/)
cleanup.sh
apt autoremove
清理 apt lists

清理 tmp

packer build -var cpu_arch=amd64 packer/templates/container/ubuntu-2404-container.pkr.hcl
packer build -var cpu_arch=arm64 packer/templates/k3s/ubuntu-2404-k3s.pkr.hcl


4. GitHub Actions Pipeline

Pipeline 负责：
Packer 构建 AMI（按 edition + Ubuntu version + arch）
AMI 复制到多 Region（如 Tokyo/HK/US-West）
Tag AMI
按 edition/version/arch 筛选 → 每 Region 仅保留 1 个 AMI
输出 AMI Map JSON（供 Terraform & Dashboard 使用）

支持矩阵
edition:        base / container / k3s / sealos / sealos-gpu
ubuntu_version: 2204 / 2404
cpu_arch:       amd64 / arm64


GitHub Actions 会自动组合出所有 Golden Image 变种。

5. Terraform: Auto-Select Latest Golden Image

模块位置：

modules/cloud_neutra_ami/
  main.tf
  variables.tf
  outputs.tf


使用方式：

module "cn_container_2404_amd64" {
  source         = "../../modules/cloud_neutra_ami"
  ubuntu_version = "2404"
  cpu_arch       = "amd64"
  edition        = "container"
}


输出：

module.cn_container_2404_amd64.id   # 最新 AMI ID
module.cn_container_2404_amd64.name # AMI 名称


Terraform 会自动从目标 Region 检索最 新 Golden Image，即使你复制了多 Region。

6. Status

Cloud-Neutra Golden Image Pipeline 已具备：
完整家族命名体系（base / container / k3s / sealos / sealos-gpu）
双 LTS / 双架构覆盖
完整 Packer 模板体系
完整统一脚本（base + flavors）
GitHub Actions 自动构建、多 Region 复制、Retention
Terraform 自动引用最新 AMI 的可重用模块
整个体系作为 Cloud-Neutra IAC/GitOps 的底座，可直接扩展到：
EKS 节点（GPU/ARM）
K3s 边缘节点
Sealos 容器云节点
大模型推理 GPU 节点
通用 Container VM
DevOps 工具链
