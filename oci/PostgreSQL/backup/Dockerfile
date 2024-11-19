FROM images.onwalk.net/public/base/python-3.10:latest

# 安装必要的软件包
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-client cron && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制依赖文件并安装 Python 库
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用程序文件
COPY backup.py restore.py utils.py config.yaml entrypoint.sh ./

# 赋予 entrypoint.sh 执行权限
RUN chmod +x /app/entrypoint.sh

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]
