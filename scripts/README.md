# Bose Predictive Maintenance System Deployment

## Overview
The `deploy.sh` script automates the deployment of the Bose Predictive Maintenance System using AWS CloudFormation, handling both initial creation and updates of the stack.

## Functionality
1. Packages the Lambda function code
2. Uploads the Lambda package to the specified S3 bucket
3. Creates or updates a CloudFormation change set
4. Displays the proposed changes
5. Prompts for confirmation before applying changes
6. Executes the change set (creates or updates the stack)
7. Sets up S3 event notifications for the created bucket

## Usage
1. Update the following variables in `deploy.sh`:
   - `STACK_NAME`: Name of your CloudFormation stack
   - `REGION`: AWS region for deployment
   - `DEPLOYMENT_BUCKET`: Name of your S3 bucket for deployment artifacts
2. Run the script: `./deploy.sh`
3. Review the proposed changes when prompted
4. Confirm to apply the changes

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- S3 bucket for storing deployment artifacts
- Permissions to create and manage CloudFormation stacks, Lambda functions, S3 buckets, and other AWS resources

## Troubleshooting
1. **S3 bucket error**: Ensure the `DEPLOYMENT_BUCKET` in the script matches an existing S3 bucket
2. **Insufficient permissions**: Verify AWS CLI is configured with necessary permissions
3. **Change set creation failed**: Check CloudFormation console for detailed error messages

## Rollback Process
To roll back changes:
1. Go to the AWS CloudFormation console
2. Select the stack
3. Choose "Roll back" from the "Stack actions" menu

Note: This will revert the stack to its previous state but won't delete data in created resources.

## Resolved Circular Dependency Issue
The previous version had a circular dependency between components, now resolved by:
1. Reorganizing utilities into more appropriate files
2. Breaking the dependency chain
3. Ensuring correct resource creation order in the CloudFormation template

This allows for a more stable and predictable deployment process.
