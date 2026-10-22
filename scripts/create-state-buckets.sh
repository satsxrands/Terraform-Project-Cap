#!/usr/bin/env bash
#
# One-time bootstrap: create the remote state bucket for each environment.
#
# Terraform cannot create the bucket that holds its own state, so this runs
# before the first `terraform init`. It is idempotent - re-running it leaves
# existing buckets in place and re-applies the same settings.
#
# Usage:
#   ./scripts/create-state-buckets.sh [prefix] [region]
#   ./scripts/create-state-buckets.sh trimm-st af-south-1
#
# Bucket names follow envs/<env>/<env>.tfbackend: <prefix>-s3-<env>
# Credentials come from the normal AWS CLI chain (profile or environment).

set -euo pipefail

PREFIX="${1:-trimm-st}"
REGION="${2:-af-south-1}"
ENVIRONMENTS=(dev qa prd)

if [[ ! "$PREFIX" =~ ^[a-z][a-z0-9-]{2,19}$ ]]; then
  echo "ERROR: prefix must be 3-20 chars: lowercase letters, digits, hyphens, starting with a letter." >&2
  exit 1
fi

account_id="$(aws sts get-caller-identity --query Account --output text)" || {
  echo "ERROR: AWS credentials are missing or invalid." >&2
  exit 1
}

echo "Account : ${account_id}"
echo "Region  : ${REGION}"
echo "Buckets : ${ENVIRONMENTS[*]/#/${PREFIX}-s3-}"
read -r -p "Create these state buckets in this account? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }

for env in "${ENVIRONMENTS[@]}"; do
  bucket="${PREFIX}-s3-${env}"

  if aws s3api head-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null; then
    echo "[${env}] ${bucket} already exists - re-applying settings"
  else
    echo "[${env}] creating ${bucket}"
    aws s3api create-bucket \
      --bucket "$bucket" \
      --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi

  aws s3api put-bucket-versioning \
    --bucket "$bucket" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$bucket" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  aws s3api put-public-access-block \
    --bucket "$bucket" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  aws s3api put-bucket-tagging \
    --bucket "$bucket" \
    --tagging "TagSet=[{Key=Environment,Value=${env}},{Key=APP,Value=capitec-terraform-training},{Key=OWNER,Value=Geeks4Learning},{Key=DEVELOPER,Value=${PREFIX}}]"

  echo "[${env}] ready: s3://${bucket}"
done

echo
echo "Done. Next: terraform init -reconfigure -backend-config=envs/<env>/<env>.tfbackend"
