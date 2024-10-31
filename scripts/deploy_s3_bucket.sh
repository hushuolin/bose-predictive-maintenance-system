#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

STACK_NAME="bose-health-data-bucket"
REGION="us-east-1"

# Deploy the S3 bucket stack if it does not exist
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    echo "Deploying S3 bucket stack..."
    aws cloudformation create-stack --stack-name $STACK_NAME \
        --template-body file://s3-bucket-template.yaml \
        --region $REGION
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    echo "S3 bucket stack deployed successfully."
else
    echo "S3 bucket stack already exists. No changes made."
fi

# Get the S3 bucket name from the stack outputs
S3_BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='BoseHealthDataBucketName'].OutputValue" \
    --output text --region $REGION)

# Construct the full ARN for the S3 bucket
S3_BUCKET_ARN="arn:aws:s3:::${S3_BUCKET_NAME}"

if [ -n "$S3_BUCKET_ARN" ]; then
    echo "S3 Bucket ARN: $S3_BUCKET_ARN"
else
    echo "Error: Unable to retrieve S3 Bucket ARN."
    exit 1
fi
