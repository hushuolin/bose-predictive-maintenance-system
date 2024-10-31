#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

STACK_NAME="bose-predictive-maintenance"
REGION="us-east-1"
DEPLOYMENT_BUCKET="bose-deployment-artifacts-742465305217"
LAMBDA_ZIP="lambda_functions.zip"
LAMBDA_FUNCTION_FILE="lambda_functions/index.py"
HEALTH_DATA_BUCKET_ARN="arn:aws:s3:::bose-health-data-742465305217"  # Set your S3 bucket ARN here

# Package the Lambda function
if [ -f "$LAMBDA_ZIP" ]; then
    rm $LAMBDA_ZIP  # Remove existing zip file if it exists
fi
zip -j $LAMBDA_ZIP $LAMBDA_FUNCTION_FILE

# Upload the Lambda package to S3
aws s3 cp $LAMBDA_ZIP s3://$DEPLOYMENT_BUCKET/$LAMBDA_ZIP

# Validate the CloudFormation template
echo "Validating CloudFormation template..."
VALIDATION_OUTPUT=$(aws cloudformation validate-template --template-body file://template.yaml 2>&1)
if [ $? -ne 0 ]; then
    echo "Template validation failed:"
    echo "$VALIDATION_OUTPUT"
    exit 1
fi

# Check if the main stack exists
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

# Create a change set for the main stack
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
        ParameterKey=HealthMetricsTableName,ParameterValue=bose-health-metrics \
        ParameterKey=MaintenanceAlertTopicName,ParameterValue=bose-maintenance-alerts \
        ParameterKey=LambdaCodeS3Bucket,ParameterValue=$DEPLOYMENT_BUCKET \
        ParameterKey=LambdaCodeS3Key,ParameterValue=$LAMBDA_ZIP \
        ParameterKey=HealthDataBucketArn,ParameterValue=$HEALTH_DATA_BUCKET_ARN

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

    # Get the Lambda function ARN from the stack outputs
    LAMBDA_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='HealthDataProcessorFunctionArn'].OutputValue" --output text --region $REGION)

    if [ -z "$LAMBDA_ARN" ]; then
        echo "Error: Unable to retrieve LAMBDA_ARN. Please check the stack outputs."
        exit 1
    fi

    # Set up S3 event notification
    echo "Setting up S3 event notification..."
    aws s3api put-bucket-notification-configuration \
        --bucket $(echo $HEALTH_DATA_BUCKET_ARN | cut -d':' -f6) \
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
rm $LAMBDA_ZIP
