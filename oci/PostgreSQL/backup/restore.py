import os
import sys
import subprocess
import logging
from utils import load_config
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

def decrypt_file(file_name, key):
    with open(file_name, 'rb') as infile:
        iv = infile.read(12)
        tag = infile.read(16)
        ciphertext = infile.read()

    if len(key) == 16 or len(key) == 32:
        algorithm = algorithms.AES(key)
        cipher = Cipher(algorithm, mode=modes.GCM(iv, tag))
    else:
        logger.error("不支持的密钥长度，必须是 16 或 32 字节（AES-128 或 AES-256）")
        sys.exit(1)

    decryptor = cipher.decryptor()
    try:
        plaintext = decryptor.update(ciphertext) + decryptor.finalize()
    except Exception as e:
        logger.error(f"解密失败：{e}")
        sys.exit(1)

    with open(file_name, 'wb') as outfile:
        outfile.write(plaintext)

def download_from_cloud(file_name):
    storage_provider = config['restore']['storage']['provider']
    if storage_provider == 'aws':
        import boto3
        s3 = boto3.client(
            's3',
            aws_access_key_id=config['restore']['storage']['access_key'],
            aws_secret_access_key=config['restore']['storage']['secret_key']
        )
        s3.download_file(config['restore']['storage']['bucket_name'], file_name, file_name)
        logger.info(f"备份文件已从 AWS S3 下载：{file_name}")
    elif storage_provider == 'aliyun':
        import oss2
        auth = oss2.Auth(
            config['restore']['storage']['access_key'],
            config['restore']['storage']['secret_key']
        )
        bucket = oss2.Bucket(auth, config['restore']['storage']['endpoint'], config['restore']['storage']['bucket_name'])
        bucket.get_object_to_file(file_name, file_name)
        logger.info(f"备份文件已从阿里云 OSS 下载：{file_name}")
    else:
        logger.error(f"不支持的存储提供商：{storage_provider}")
        sys.exit(1)

def restore():
    logger.info("开始恢复过程")
    source = config['restore']['source']
    storage_provider = config['restore']['storage']['provider']
    bucket_name = config['restore']['storage']['bucket_name']

    # 如果 source 是 'latest'，获取最新的备份文件名
    if source == 'latest':
        if storage_provider == 'aws':
            import boto3
            s3 = boto3.client(
                's3',
                aws_access_key_id=config['restore']['storage']['access_key'],
                aws_secret_access_key=config['restore']['storage']['secret_key']
            )
            objects = s3.list_objects_v2(Bucket=bucket_name)
            backups = [obj['Key'] for obj in objects.get('Contents', []) if obj['Key'].startswith('backup_')]
        elif storage_provider == 'aliyun':
            import oss2
            auth = oss2.Auth(
                config['restore']['storage']['access_key'],
                config['restore']['storage']['secret_key']
            )
            bucket = oss2.Bucket(auth, config['restore']['storage']['endpoint'], bucket_name)
            backups = [obj.key for obj in oss2.ObjectIterator(bucket) if obj.key.startswith('backup_')]
        else:
            logger.error(f"不支持的存储提供商：{storage_provider}")
            sys.exit(1)

        if not backups:
            logger.error("未找到任何备份文件")
            sys.exit(1)
        backups.sort()
        source = backups[-1]  # 获取最新的备份文件名

    # 下载备份文件
    logger.info(f"正在下载备份文件：{source}")
    download_from_cloud(source)

    # 默认启用加密
    encryption_enabled = config['backup'].get('encryption', True)
    if encryption_enabled:
        key = load_encryption_key()
        decrypt_file(source, key)
        logger.info(f"备份文件已解密：{source}")

    # 使用 pg_restore 恢复数据库
    pg_restore_cmd = [
        'pg_restore',
        '-h', os.environ.get('DB_HOST', 'localhost'),
        '-U', os.environ.get('DB_USER', 'postgres'),
        '-d', os.environ.get('DB_NAME', 'postgres'),
        '--clean',  # 在恢复前删除现有的对象
        source
    ]
    try:
        subprocess.run(pg_restore_cmd, check=True, env=os.environ)
        logger.info("数据库恢复完成")
    except subprocess.CalledProcessError as e:
        logger.error(f"数据库恢复失败：{e}")
        sys.exit(1)

    # 删除本地备份文件
    os.remove(source)
    logger.info("本地备份文件已删除")

if __name__ == "__main__":
    if 'run_restore' in sys.argv:
        restore()
    else:
        logger.error("请指定 'run_restore'")
