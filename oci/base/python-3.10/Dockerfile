# 使用官方的 Python 3.10 运行时作为基础镜像
FROM python:3.10-slim

# 将该镜像标记为 python-3.10 基础镜像
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

# 安装必要的软件包
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cron && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app
