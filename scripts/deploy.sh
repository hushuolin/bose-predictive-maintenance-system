#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

STACK_NAME="bose-predictive-maintenance"
REGION="us-east-1"
DEPLOYMENT_BUCKET="bose-deployment-artifacts-742465305217"

# Package the Lambda function
zip -j lambda.zip lambda/index.py

# Upload the Lambda package to S3
aws s3 cp lambda.zip s3://$DEPLOYMENT_BUCKET/lambda.zip

# Check if the stack exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    STACK_EXISTS=true
else
    STACK_EXISTS=false
fi

# Set the appropriate action based on stack existence
if $STACK_EXISTS; then
    ACTION="update"
    CHANGE_SET_TYPE="UPDATE"
else
    ACTION="create"
    CHANGE_SET_TYPE="CREATE"
fi

# Create a change set
echo "Creating change set for stack $ACTION..."
CHANGE_SET_NAME="changeset-$(date +%Y%m%d%H%M%S)"
aws cloudformation create-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --change-set-type $CHANGE_SET_TYPE \
    --template-body file://template.yaml \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --parameters \
        ParameterKey=HealthDataBucketName,ParameterValue=bose-health-data-$(date +%Y%m%d%H%M%S) \
        ParameterKey=HealthMetricsTableName,ParameterValue=bose-health-metrics \
        ParameterKey=MaintenanceAlertTopicName,ParameterValue=bose-maintenance-alerts \
        ParameterKey=LambdaCodeS3Bucket,ParameterValue=$DEPLOYMENT_BUCKET \
        ParameterKey=LambdaCodeS3Key,ParameterValue=lambda.zip

# Wait for change set creation to complete
echo "Waiting for change set creation to complete..."
aws cloudformation wait change-set-create-complete \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --region $REGION

# Describe the change set
echo "Changes to be applied:"
aws cloudformation describe-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --query 'Changes[].{Action:ResourceChange.Action, LogicalResourceId:ResourceChange.LogicalResourceId, ResourceType:ResourceChange.ResourceType}' \
    --output table \
    --region $REGION

# Ask for confirmation
read -p "Do you want to execute the change set to $ACTION the stack? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Execute the change set
    echo "Executing change set..."
    aws cloudformation execute-change-set \
        --stack-name $STACK_NAME \
        --change-set-name $CHANGE_SET_NAME \
        --region $REGION

    # Wait for stack update/creation to complete
    echo "Waiting for stack $ACTION to complete..."
    if $STACK_EXISTS; then
        aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
    else
        aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    fi

    echo "Stack $ACTION completed successfully."

    # Get the S3 bucket name and Lambda function ARN from the stack outputs
    S3_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='HealthDataBucketName'].OutputValue" --output text --region $REGION)
    LAMBDA_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='HealthDataProcessorFunctionArn'].OutputValue" --output text --region $REGION)

    # Set up S3 event notification
    echo "Setting up S3 event notification..."
    aws s3api put-bucket-notification-configuration \
        --bucket $S3_BUCKET \
        --notification-configuration '{
            "LambdaFunctionConfigurations": [{
                "LambdaFunctionArn": "'"$LAMBDA_ARN"'",
                "Events": ["s3:ObjectCreated:*"]
            }]
        }' \
        --region $REGION

    echo "Deployment completed successfully."
else
    echo "Change set execution cancelled."
fi

# Clean up local files
rm lambda.zip