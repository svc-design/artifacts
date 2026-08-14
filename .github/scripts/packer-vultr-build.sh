#!/usr/bin/env bash
set -euo pipefail

: "${TEMPLATE:?TEMPLATE must be set}"
: "${SOURCE_NAME:?SOURCE_NAME must be set}"
: "${VULTR_API_KEY:?VULTR_API_KEY must be set}"
: "${VULTR_REGION_ID:?VULTR_REGION_ID must be set}"
: "${VULTR_PLAN_ID:?VULTR_PLAN_ID must be set}"
: "${VULTR_OS_REGEX:?VULTR_OS_REGEX must be set}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

template_path="$TEMPLATE"
template_path="${template_path#packer/}"
cd "${repo_root}/packer"

for command_name in curl jq packer tee; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is not installed: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "$template_path" ]]; then
  echo "Packer template does not exist: ${repo_root}/packer/${template_path}" >&2
  exit 1
fi

os_id="${VULTR_OS_ID:-}"
if [[ -z "$os_id" ]]; then
  os_id="$("${script_dir}/resolve-vultr-os-id.sh" "$VULTR_OS_REGEX")"
fi

if [[ ! "$os_id" =~ ^[0-9]+$ || "$os_id" == "0" ]]; then
  echo "VULTR_OS_ID must be a positive numeric Vultr OS ID, got: ${os_id}" >&2
  exit 1
fi

snapshot_description="${VULTR_SNAPSHOT_DESCRIPTION:-golden-${SOURCE_NAME}-${GITHUB_RUN_ID:-local}}"
packer_log="${PACKER_LOG:-packer-${SOURCE_NAME}.log}"
if [[ "$packer_log" != /* ]]; then
  packer_log="${repo_root}/${packer_log}"
fi

packer init "$template_path"

packer_vars=(
  "-var=vultr_os_id=${os_id}"
  "-var=vultr_region_id=${VULTR_REGION_ID}"
  "-var=vultr_plan_id=${VULTR_PLAN_ID}"
  "-var=vultr_snapshot_description=${snapshot_description}"
)

packer validate "${packer_vars[@]}" "$template_path"

echo "Building ${TEMPLATE} with Vultr source ${SOURCE_NAME}"
echo "Vultr region=${VULTR_REGION_ID}, plan=${VULTR_PLAN_ID}, os_id=${os_id}"
echo "Snapshot description=${snapshot_description}"

packer build -color=false -only="vultr.${SOURCE_NAME}" "${packer_vars[@]}" "$template_path" \
  2>&1 | tee "$packer_log"

snapshot_id="$(sed -nE 's/.*Vultr Snapshot: .* \(([[:alnum:]-]+)\).*/\1/p' "$packer_log" | tail -n 1)"
if [[ -z "$snapshot_id" ]]; then
  snapshot_id="$(curl --silent --show-error --fail --compressed \
    --header "Authorization: Bearer ${VULTR_API_KEY}" \
    --header "Content-Type: application/json" \
    "https://api.vultr.com/v2/snapshots" \
    | jq -r --arg description "$snapshot_description" '
      .snapshots[] | select(.description == $description) | .id
    ' | head -n 1)"
fi

if [[ -z "$snapshot_id" || "$snapshot_id" == "null" ]]; then
  echo "Packer completed, but the Vultr snapshot ID could not be determined." >&2
  exit 1
fi

snapshot_status="$(curl --silent --show-error --fail --compressed \
  --header "Authorization: Bearer ${VULTR_API_KEY}" \
  --header "Content-Type: application/json" \
  "https://api.vultr.com/v2/snapshots/${snapshot_id}" \
  | jq -r '.snapshot.status')"

if [[ "$snapshot_status" != "complete" ]]; then
  echo "Vultr snapshot ${snapshot_id} is not complete: ${snapshot_status}" >&2
  exit 1
fi

echo "Vultr snapshot published: ${snapshot_id}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "snapshot_id=${snapshot_id}"
    echo "os_id=${os_id}"
    echo "snapshot_description=${snapshot_description}"
  } >>"$GITHUB_OUTPUT"
fi

# Clean up historical Golden Image snapshots, keeping only the latest version
echo "======================================================="
echo " Cleaning up historical Golden Image snapshots on Vultr"
echo " (Keeping latest: ${snapshot_id} - ${snapshot_description})"
echo "======================================================="

all_snapshots_json="$(curl --silent --show-error --fail --compressed \
  --header "Authorization: Bearer ${VULTR_API_KEY}" \
  --header "Content-Type: application/json" \
  "https://api.vultr.com/v2/snapshots" || true)"

if [[ -n "$all_snapshots_json" ]]; then
  old_snapshot_ids=$(echo "$all_snapshots_json" | jq -r --arg current "$snapshot_id" --arg src1 "golden-${SOURCE_NAME}" --arg src2 "${SOURCE_NAME}-golden" '
    .snapshots[]?
    | select((.description | startswith($src1)) or (.description | contains($src1)) or (.description | contains($src2)))
    | select(.id != $current)
    | .id
  ')

  if [[ -n "$old_snapshot_ids" ]]; then
    for old_id in $old_snapshot_ids; do
      echo "Pruning older snapshot on Vultr: ${old_id}"
      curl --silent --show-error --fail \
        -X DELETE \
        --header "Authorization: Bearer ${VULTR_API_KEY}" \
        "https://api.vultr.com/v2/snapshots/${old_id}" || echo "Warning: failed to delete ${old_id}"
      echo "Successfully purged older snapshot: ${old_id}"
    done
  else
    echo "No older historical snapshots found for ${SOURCE_NAME}."
  fi
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Vultr Golden Image"
    echo
    echo "- Template: \`${TEMPLATE}\`"
    echo "- Snapshot ID: \`${snapshot_id}\`"
    echo "- Snapshot description: \`${snapshot_description}\`"
    echo "- Region: \`${VULTR_REGION_ID}\`"
    echo "- Plan: \`${VULTR_PLAN_ID}\`"
    echo "- OS ID: \`${os_id}\`"
  } >>"$GITHUB_STEP_SUMMARY"
fi
