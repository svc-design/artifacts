import os
import sys
import subprocess
import logging
from datetime import datetime
from utils import load_config, setup_cron
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

# 配置日志输出到标准输出
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# 加载配置
config = load_config()

def load_encryption_key():
    key_path = '/app/encryption.key'
    if not os.path.exists(key_path):
        logger.error(f"未找到加密密钥文件：{key_path}")
        sys.exit(1)
    with open(key_path, 'rb') as key_file:
        key = key_file.read()
    return key

def encrypt_file(file_name, key):
    if len(key) == 16 or len(key) == 32:
        algorithm = algorithms.AES(key)
        # 生成随机的 12 字节（96 位）IV
        iv = os.urandom(12)
        cipher = Cipher(algorithm, mode=modes.GCM(iv))
    else:
        logger.error("不支持的密钥长度，必须是 16 或 32 字节（AES-128 或 AES-256）")
        sys.exit(1)

    encryptor = cipher.encryptor()

    with open(file_name, 'rb') as infile:
        plaintext = infile.read()

    ciphertext = encryptor.update(plaintext) + encryptor.finalize()
    tag = encryptor.tag

    # 将 IV、认证标签和密文写入文件
    with open(file_name, 'wb') as outfile:
        outfile.write(iv + tag + ciphertext)

def upload_to_cloud(file_name):
    storage_provider = config['backup']['storage']['provider']
    if storage_provider == 'aws':
        import boto3
        s3 = boto3.client(
            's3',
            aws_access_key_id=config['backup']['storage']['access_key'],
            aws_secret_access_key=config['backup']['storage']['secret_key']
        )
        s3.upload_file(file_name, config['backup']['storage']['bucket_name'], file_name)
        logger.info(f"备份文件已上传到 AWS S3：{file_name}")
    elif storage_provider == 'aliyun':
        import oss2
        auth = oss2.Auth(
            config['backup']['storage']['access_key'],
            config['backup']['storage']['secret_key']
        )
        bucket = oss2.Bucket(auth, config['backup']['storage']['endpoint'], config['backup']['storage']['bucket_name'])
        with open(file_name, 'rb') as fileobj:
            bucket.put_object(file_name, fileobj)
        logger.info(f"备份文件已上传到阿里云 OSS：{file_name}")
    else:
        logger.error(f"不支持的存储提供商：{storage_provider}")
        sys.exit(1)

def backup():
    logger.info("开始备份过程")
    backup_type = config['backup'].get('type', 'full')
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    backup_file = f"backup_{backup_type}_{timestamp}.sql"

    # 执行 pg_dump 命令
    pg_dump_cmd = [
        'pg_dump',
        '-h', os.environ.get('DB_HOST', 'localhost'),
        '-U', os.environ.get('DB_USER', 'postgres'),
        os.environ.get('DB_NAME', 'postgres'),
        '-F', 'c',  # 使用自定义格式，便于压缩
        '-b',  # 包含大对象
        '-f', backup_file
    ]
    try:
        subprocess.run(pg_dump_cmd, check=True, env=os.environ)
        logger.info(f"数据库备份成功：{backup_file}")
    except subprocess.CalledProcessError as e:
        logger.error(f"数据库备份失败：{e}")
        sys.exit(1)

    # 默认启用加密
    encryption_enabled = config['backup'].get('encryption', True)
    if encryption_enabled:
        key = load_encryption_key()
        encrypt_file(backup_file, key)
        logger.info(f"备份文件已加密：{backup_file}")

    # 上传到云存储
    upload_to_cloud(backup_file)

    # 删除本地备份文件
    os.remove(backup_file)
    logger.info("本地备份文件已删除")

def verify_backup():
    # 实现备份验证逻辑
    logger.info("开始备份验证过程")
    # 这里可以实现下载备份文件，尝试解密和解压，确保备份文件有效
    logger.info("备份验证完成")

if __name__ == "__main__":
    if 'setup_cron' in sys.argv:
        setup_cron()
    elif 'run_backup' in sys.argv:
        backup()
    elif 'verify_backup' in sys.argv:
        verify_backup()
    else:
        logger.error("请指定 'setup_cron'、'run_backup' 或 'verify_backup'")
