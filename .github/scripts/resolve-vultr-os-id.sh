#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "usage: $0 <OS-name-regex>" >&2
  exit 2
fi

: "${VULTR_API_KEY:?VULTR_API_KEY must be set}"

os_name_regex="$1"
api_response="$(curl --silent --show-error --fail --compressed \
  --header "Authorization: Bearer ${VULTR_API_KEY}" \
  --header "Content-Type: application/json" \
  "https://api.vultr.com/v2/os")"

os_id="$(jq -r --arg pattern "$os_name_regex" '
  .os[]
  | select((.arch == "x64" or .arch == "x86_64") and (.name | test($pattern; "i")))
  | .id
' <<<"$api_response" | head -n 1)"

if [[ -z "$os_id" || "$os_id" == "null" ]]; then
  echo "No x64 Vultr OS matched regex: ${os_name_regex}" >&2
  echo "Available matching candidates:" >&2
  jq -r --arg pattern "$os_name_regex" '
    .os[] | select(.name | test($pattern; "i")) | "\(.id)\t\(.name)\t\(.arch)"
  ' <<<"$api_response" >&2
  exit 1
fi

echo "$os_id"
