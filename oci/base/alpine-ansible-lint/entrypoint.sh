#!/bin/sh
# required by Jenkins Docker plugin: https://github.com/docker-library/official-images#consistency
# https://issues.jenkins.io/browse/JENKINS-51307?focusedCommentId=341121&page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel

set -e

echo "Starting entrypoint script..."

# Check if there was a command passed
if [ "$1" ]; then
    echo "Executing passed command: $@"
    exec "$@"
else
    echo "No command provided, running default application..."
    # 在这里指定一个默认命令，如果通常没有特定的命令需要执行
    exec /bin/bash
fi
