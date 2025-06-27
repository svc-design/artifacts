#!/bin/bash
set -euo pipefail

AUTO_FIX=false

# 检查是否带 --fix 参数
if [[ "${1:-}" == "--fix" ]]; then
  AUTO_FIX=true
fi

echo "🔍 Checking NVIDIA GPU status..."

# 1. 检查是否识别 GPU
echo -e "\n📦 [1] PCI 设备检测:"
if lspci | grep -i nvidia; then
  echo "✅ 已检测到 NVIDIA GPU"
else
  echo "❌ 未检测到 GPU，请检查硬件绑定或云平台配置"
  exit 1
fi

# 2. 检查内核模块
echo -e "\n📦 [2] 内核模块检测:"
if lsmod | grep -q nvidia; then
  echo "✅ nvidia 模块已加载"
else
  echo "❌ nvidia 模块未加载"
  echo "👉 尝试执行：sudo modprobe nvidia"
fi

# 3. 检查设备节点
echo -e "\n📦 [3] 设备节点检测:"
if ls /dev/nvidia0 &>/dev/null; then
  echo "✅ /dev/nvidia0 存在"
else
  echo "❌ 缺少 /dev/nvidia0，驱动可能未成功加载"
fi

# 4. 检查 nvidia-smi
echo -e "\n📦 [4] 驱动状态检测 (nvidia-smi):"
if command -v nvidia-smi &>/dev/null; then
  if nvidia-smi; then
    echo "✅ nvidia-smi 正常"
  else
    echo "❌ nvidia-smi 执行失败，驱动可能未正确绑定设备"
  fi
else
  echo "❌ 未安装 nvidia-smi 工具"
  echo "👉 需安装驱动包 nvidia-driver-535、nvidia-utils-535 等"
  if $AUTO_FIX; then
    echo -e "\n⚙️ 正在自动安装驱动..."
    sudo apt-get update
    sudo apt-get install -y nvidia-driver-535 nvidia-utils-535 dkms linux-headers-$(uname -r)
    echo -e "\n✅ 驱动安装完成，请重启后再运行本脚本确认"
    exit 0
  else
    echo -e "\n👉 可执行以下命令安装推荐驱动："
    echo "sudo apt-get update && sudo apt-get install -y nvidia-driver-535 nvidia-utils-535 dkms linux-headers-\$(uname -r)"
  fi
fi

# 5. dmesg 错误日志
echo -e "\n📦 [5] dmesg 日志（最近 NVIDIA 行）:"
dmesg | grep -i nvidia | tail -n 20 || echo "ℹ️ 无 NVIDIA 错误日志"

# 6. nerdctl 测试（可选）
if command -v nerdctl &>/dev/null; then
  echo -e "\n📦 [6] nerdctl GPU 容器测试:"
  if nerdctl run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi; then
    echo "✅ nerdctl 能访问 GPU"
  else
    echo "❌ nerdctl 无法访问 GPU"
  fi
else
  echo -e "\n📦 [6] nerdctl 未安装，跳过容器测试"
fi

echo -e "\n🎉 GPU 检查完成"
