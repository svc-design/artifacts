目录结构
├── Dockerfile
├── entrypoint.sh
├── requirements.txt
├── backup.py
├── restore.py
├── utils.py
├── config.yaml
```i
构建和运行容器
构建镜像：
bash
复制代码
docker build -t postgres-backup:latest .
运行容器：
步骤 1：生成加密密钥
安装 cryptography 库（如果尚未安装）：

bash
复制代码
pip install cryptography
生成 AES-256 位加密密钥：

bash
复制代码
python generate_key.py AES-256 /path/to/your/encryption.key
步骤 2：设置文件权限
bash
复制代码
chmod 600 /path/to/your/encryption.key
步骤 3：运行 Docker 容器
bash
复制代码
docker run -d \
  --name postgres-backup-container \
  -v /path/to/your/config.yaml:/app/config.yaml \
  -v /path/to/your/encryption.key:/app/encryption.key \
  -e DB_HOST=your_db_host \
  -e DB_USER=your_db_user \
  -e DB_NAME=your_db_name \
  postgres-backup:latest

请根据您的实际数据库连接信息替换 your_db_host、your_db_user 和 your_db_name。

运行示例
备份
手动执行备份：

bash
复制代码
python /app/backup.py run_backup
恢复
手动执行恢复：

bash
复制代码
python /app/restore.py run_restore
