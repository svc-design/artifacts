#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <github_repo> <tag_regex> [human_readable_pattern]" >&2
  exit 1
fi

GH_REPO="$1"
TAG_REGEX="$2"
PATTERN_DESC="${3:-$TAG_REGEX}"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

gh api -H "Accept: application/vnd.github+json" \
  "/repos/${GH_REPO}/releases?per_page=100" \
  | jq -r '.[].tag_name // empty' \
  | grep -E "${TAG_REGEX}" \
  | sort -V -r \
  | head -n 1 > "$TMP_FILE"

if [ ! -s "$TMP_FILE" ]; then
  echo "No tags matching pattern (${PATTERN_DESC}) found for ${GH_REPO}." >&2
  exit 1
fi

cat "$TMP_FILE"
