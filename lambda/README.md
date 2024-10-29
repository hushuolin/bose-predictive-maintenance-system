# Health Data Processor Lambda Function

This Lambda function processes health data for the Bose Predictive Maintenance System. It's triggered by S3 events when new health data files are uploaded.

## Overview

The function performs the following tasks:
1. Retrieves health data files from S3
2. Processes and stores the data in DynamoDB
3. Checks for anomalies in the data
4. Sends alerts via SNS if anomalies are detected

## Function Details

### Dependencies
- `json`: For parsing JSON data
- `boto3`: AWS SDK for Python, used to interact with AWS services
- `os`: For accessing environment variables

### AWS Services Used
- Amazon S3: Source of health data files
- Amazon DynamoDB: Storage for processed health data
- Amazon SNS: For sending alerts

### Environment Variables
- `HEALTH_METRICS_TABLE`: Name of the DynamoDB table for storing health metrics
- `ALERT_TOPIC_ARN`: ARN of the SNS topic for sending alerts

### Main Handler: `handler(event, context)`
- Triggered by S3 events
- Iterates through S3 event records
- Retrieves and processes each uploaded file

### Helper Functions

#### `process_health_data(health_data)`
- Stores each item from the health data in DynamoDB
- Checks for anomalies and sends alerts if necessary

#### `check_for_anomalies(item)`
- Implements anomaly detection logic
- Currently checks for low battery level (<10%) or high temperature (>50°C)
- Can be extended with more sophisticated anomaly detection algorithms

#### `send_alert(item, topic_arn)`
- Sends an alert message to the specified SNS topic
- Alert includes product ID, battery level, and temperature

## Input Format

The function expects the S3 file to contain a JSON array of health data items. Each item should have the following structure:

```json
{
  "productId": "string",
  "batteryLevel": number,
  "temperature": number,
  // Other relevant health metrics...
}
```

## Error Handling
- Uses AWS Lambda's default error handling and logging
- Errors logged to CloudWatch Logs
- No custom retry logic for failed operations

## Scalability and Performance
- Processes each file sequentially
- For large files or high-frequency uploads:
  - Consider implementing batch processing
  - Or use AWS Step Functions for orchestration

## Security Considerations
- Ensure Lambda's IAM role has minimum necessary permissions for S3, DynamoDB, and SNS
- Use encryption for sensitive data in transit and at rest
- Regularly review and rotate access keys and permissions

## Future Improvements
- Implement more sophisticated anomaly detection algorithms
- Add error handling and retries for DynamoDB and SNS operations
- Implement batching for more efficient DynamoDB writes
- Add input validation and error handling for malformed input data
