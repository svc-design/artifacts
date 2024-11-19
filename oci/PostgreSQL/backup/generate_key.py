import os
import sys
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import constant_time
from cryptography.hazmat.backends import default_backend

def generate_key(strength, key_file_path):
    # 验证加密强度参数
    if strength not in ['AES-128', 'AES-256', 'AES-512']:
        print("错误：加密强度必须是 AES-128、AES-256 或 AES-512")
        sys.exit(1)

    # 设置密钥长度
    if strength == 'AES-128':
        key_length = 16  # 16 字节 = 128 位
    elif strength == 'AES-256':
        key_length = 32  # 32 字节 = 256 位
    elif strength == 'AES-512':
        key_length = 64  # 64 字节 = 512 位（非标准 AES 密钥长度）

    # 生成随机密钥
    key = os.urandom(key_length)

    # 将密钥写入指定的文件路径
    with open(key_file_path, 'wb') as key_file:
        key_file.write(key)

    print(f'加密密钥已生成并保存到 {key_file_path}，密钥强度：{strength}')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("用法：python generate_key.py AES-128|AES-256|AES-512 /path/to/your/encryption.key")
        sys.exit(1)

    strength = sys.argv[1]
    key_file_path = sys.argv[2]

    generate_key(strength, key_file_path)
