#!/bin/sh
set -e

# check if there was a command passed
# required by Jenkins Docker plugin: https://github.com/docker-library/official-images#consistency
# https://issues.jenkins.io/browse/JENKINS-51307?focusedCommentId=341121&page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel
if [ "$1" ]; then
    # execute it
    exec "$@"
fi
