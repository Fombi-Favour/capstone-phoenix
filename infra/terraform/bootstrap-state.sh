#!/usr/bin/env bash

set -euo pipefail

REGION="eu-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="taskapp-tfstate-${ACCOUNT_ID}"
TABLE="taskapp-tfstate-lock"

echo "==> Creating S3 bucket: ${BUCKET}"
aws s3api create-bucket \
  --bucket "${BUCKET}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

echo "==> Enabling versioning on ${BUCKET}"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling server-side encryption on ${BUCKET}"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "==> Blocking all public access on ${BUCKET}"
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Creating DynamoDB lock table: ${TABLE}"
aws dynamodb create-table \
  --table-name "${TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}"

echo ""
echo "Done! Update backend.hcl with:"
echo "  bucket = \"${BUCKET}\""
echo "  dynamodb_table = \"${TABLE}\""
