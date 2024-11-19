#!/bin/bash

# 调用 backup.py 的 setup_cron 功能，生成 cron 配置
python /app/backup.py setup_cron

# 以前台模式启动 cron 服务
cron -f
