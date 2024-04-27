#!/bin/bash

set -x

git version

# Configure git to allow all directories
git config --global --add safe.directory '*'

# Get the latest tag containing the HEAD
TAG=$(git tag --contains HEAD | head -n 1)

# Get the short commit ID
SHORT_COMMIT_ID=$(echo $GITHUB_SHA | cut -c1-7)

# Get the current branch name
BRANCH_NAME=$(git branch --show-current)

# Logic to set the build tag based on branch and tag status
if [[ "$BRANCH_NAME" == "main" ]]; then
    echo "BUILD_TAG=latest" >> $GITHUB_ENV
elif [[ "$BRANCH_NAME" =~ ^(r|release).* ]] && [[ -z "$TAG" ]]; then
    PR_ID=$(git log | grep "Merge pull request" | head -n 1 | awk -F# '{print $2}' | awk '{print $1}')
    echo "BUILD_TAG=PR-${PR_ID}-$SHORT_COMMIT_ID" >> $GITHUB_ENV
elif [[ "$BRANCH_NAME" =~ ^(r|release).* ]] && [[ ! -z "$TAG" ]]; then
    echo "BUILD_TAG=$TAG" >> $GITHUB_ENV
else
    JIRA_TICKET=$(git branch | grep '^\*' | awk '{print $2}' | awk -F- '{print $1"-"$2}')
    echo "BUILD_TAG=$JIRA_TICKET-$SHORT_COMMIT_ID" >> $GITHUB_ENV
fi
