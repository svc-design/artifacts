#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <AMI_ID> <EDITION> <UBUNTU_VERSION> <CPU_ARCH> <BASE_REGION> "<TARGET_REGIONS>" <PROJECT_TAG>

Example:
  $0 ami-1234567890 base 2204 amd64 ap-northeast-1 "ap-northeast-1 ap-east-1" Cloud-Neutra
USAGE
}

if [ "$#" -ne 7 ]; then
  echo "[ami-replicate] ERROR: Invalid arguments" >&2
  usage
  exit 1
fi

AMI_ID="$1"
EDITION="$2"
UBUNTU_VERSION="$3"
CPU_ARCH="$4"
BASE_REGION="$5"
TARGET_REGIONS_STR="$6"
PROJECT_TAG="$7"

if ! command -v aws >/dev/null 2>&1; then
  echo "[ami-replicate] ERROR: aws CLI is required." >&2
  exit 1
fi

if [ -z "$TARGET_REGIONS_STR" ]; then
  echo "[ami-replicate] ERROR: TARGET_REGIONS cannot be empty." >&2
  exit 1
fi

# Normalize target regions into an array
IFS=' ' read -r -a TARGET_REGIONS <<< "$TARGET_REGIONS_STR"

if [ "${#TARGET_REGIONS[@]}" -eq 0 ]; then
  echo "[ami-replicate] ERROR: No target regions provided." >&2
  exit 1
fi

# Fetch AMI metadata from base region
read -r IMAGE_NAME IMAGE_DESC <<< "$(aws ec2 describe-images \
  --region "$BASE_REGION" \
  --image-ids "$AMI_ID" \
  --query 'Images[0].[Name,Description]' \
  --output text)"

if [ -z "$IMAGE_NAME" ] || [ "$IMAGE_NAME" = "None" ]; then
  echo "[ami-replicate] ERROR: Unable to resolve AMI name for $AMI_ID in $BASE_REGION" >&2
  exit 1
fi

if [ -z "$IMAGE_DESC" ] || [ "$IMAGE_DESC" = "None" ]; then
  IMAGE_DESC="Cloud-Neutra ${EDITION} image Ubuntu ${UBUNTU_VERSION} ${CPU_ARCH}"
fi

TAG_SET=(
  Key=Name,Value="$IMAGE_NAME"
  Key=Project,Value="$PROJECT_TAG"
  Key=Edition,Value="$EDITION"
  Key=UbuntuVersion,Value="$UBUNTU_VERSION"
  Key=Architecture,Value="$CPU_ARCH"
  Key=Role,Value=Golden-Image
  Key=SourceRegion,Value="$BASE_REGION"
)

for REGION in "${TARGET_REGIONS[@]}"; do
  if [ "$REGION" = "$BASE_REGION" ]; then
    echo "[ami-replicate] Skip base region $BASE_REGION"
    continue
  fi

  echo "[ami-replicate] Replicating $AMI_ID ($IMAGE_NAME) to $REGION ..."

  NEW_AMI_ID=$(aws ec2 copy-image \
    --region "$REGION" \
    --source-region "$BASE_REGION" \
    --source-image-id "$AMI_ID" \
    --name "$IMAGE_NAME" \
    --description "$IMAGE_DESC" \
    --query 'ImageId' \
    --output text)

  echo "[ami-replicate] Waiting for AMI $NEW_AMI_ID in $REGION to become available ..."
  aws ec2 wait image-available --region "$REGION" --image-ids "$NEW_AMI_ID"

  echo "[ami-replicate] Tagging AMI $NEW_AMI_ID in $REGION"
  aws ec2 create-tags --region "$REGION" --resources "$NEW_AMI_ID" --tags "${TAG_SET[@]}"

  SNAPSHOT_IDS=$(aws ec2 describe-images \
    --region "$REGION" \
    --image-ids "$NEW_AMI_ID" \
    --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' \
    --output text)

  if [ -n "$SNAPSHOT_IDS" ]; then
    for SNAP_ID in $SNAPSHOT_IDS; do
      echo "[ami-replicate] Tagging snapshot $SNAP_ID in $REGION"
      aws ec2 create-tags --region "$REGION" --resources "$SNAP_ID" --tags "${TAG_SET[@]}"
    done
  fi

  echo "[ami-replicate] Completed replication to $REGION (AMI: $NEW_AMI_ID)"
done

echo "[ami-replicate] Replication process finished."
