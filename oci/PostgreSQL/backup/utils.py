import os
import yaml

def load_config():
    with open('/app/config.yaml', 'r') as file:
        config = yaml.safe_load(file)
    return config

def setup_cron():
    config = load_config()
    cron_jobs = []

    # 添加备份任务
    backup_schedule = config['backup'].get('schedule')
    if backup_schedule:
        backup_command = f"/usr/bin/python /app/backup.py run_backup >> /proc/1/fd/1 2>&1"
        cron_jobs.append(f"{backup_schedule} {backup_command}")

    # 添加验证任务
    verification_enabled = config['verification'].get('enabled', False)
    if verification_enabled:
        verification_schedule = config['verification'].get('schedule')
        if verification_schedule:
            verify_command = f"/usr/bin/python /app/backup.py verify_backup >> /proc/1/fd/1 2>&1"
            cron_jobs.append(f"{verification_schedule} {verify_command}")

    # 添加恢复任务（如果需要自动恢复）
    # restore_schedule = config['restore'].get('schedule')
    # if restore_schedule:
    #     restore_command = f"/usr/bin/python /app/restore.py run_restore >> /proc/1/fd/1 2>&1"
    #     cron_jobs.append(f"{restore_schedule} {restore_command}")

    # 将所有 cron 任务写入文件
    with open('/etc/cron.d/backup-cron', 'w') as cron_file:
        for job in cron_jobs:
            cron_file.write(f"{job}\n")

    # 赋予 cron 任务文件适当的权限
    os.chmod('/etc/cron.d/backup-cron', 0o644)
