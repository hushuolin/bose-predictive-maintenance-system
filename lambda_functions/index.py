import json
import boto3
import os
import logging
from botocore.exceptions import ClientError
from decimal import Decimal  # Import Decimal for DynamoDB compatibility

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

def handler(event, context):
    # Validate event structure
    if 'Records' not in event or not event['Records']:
        logger.error("Invalid event structure: no records found")
        return {'statusCode': 400, 'body': 'Invalid event structure: no records found'}
    
    try:
        for record in event['Records']:
            # Check remaining time
            if hasattr(context, 'get_remaining_time_in_millis') and context.get_remaining_time_in_millis() < 10000:  # 10 seconds
                logger.warning("Function is about to timeout. Stopping processing.")
                break
            
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Get the file from S3
            response = s3.get_object(Bucket=bucket, Key=key)
            file_content = response['Body'].read().decode('utf-8')
            
            # Parse JSON content
            try:
                health_data = json.loads(file_content, parse_float=Decimal)  # Use Decimal for float values
            except json.JSONDecodeError as e:
                logger.error(f"Error decoding JSON from S3 object: {e}")
                return {'statusCode': 400, 'body': 'Invalid JSON format in S3 object'}
            
            # Ensure health_data is a list
            if not isinstance(health_data, list):
                logger.error("Invalid health_data format: expected a list")
                return {'statusCode': 400, 'body': 'Invalid health_data format: expected a list'}
            
            # Process and store the health data
            process_health_data(health_data)
        
        return {'statusCode': 200, 'body': 'Health data processed successfully'}
    
    except ClientError as e:
        logger.error(f"AWS ClientError: {e}")
        return {'statusCode': 500, 'body': 'AWS service call failed'}
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {'statusCode': 500, 'body': 'Internal server error'}

def process_health_data(health_data):
    table_name = os.getenv('HEALTH_METRICS_TABLE')
    alert_topic_arn = os.getenv('ALERT_TOPIC_ARN')
    
    if not table_name or not alert_topic_arn:
        logger.error("Missing environment variables: HEALTH_METRICS_TABLE or ALERT_TOPIC_ARN")
        raise ValueError("Environment variables HEALTH_METRICS_TABLE and ALERT_TOPIC_ARN must be set")

    table = dynamodb.Table(table_name)
    
    try:
        with table.batch_writer() as batch:
            for item in health_data:
                # Convert float values to Decimal for DynamoDB
                item = {k: (Decimal(str(v)) if isinstance(v, float) else v) for k, v in item.items()}
                
                # Store in DynamoDB using batch writer
                batch.put_item(Item=item)

                # Check for anomalies and send alert if necessary
                if check_for_anomalies(item):
                    send_alert(item, alert_topic_arn)
    except ClientError as e:
        logger.error(f"Error writing to DynamoDB: {e}")
    except Exception as e:
        logger.error(f"Unexpected error in process_health_data: {e}")

def check_for_anomalies(item):
    # Implement your anomaly detection logic here
    # For example, check if battery level is too low or temperature is too high
    return item.get('batteryLevel', Decimal(1)) < Decimal('0.1') or item.get('temperature', Decimal(0)) > Decimal('50')

def send_alert(item, topic_arn):
    message = f"Alert for product {item.get('productId', 'Unknown')}: Battery level: {item.get('batteryLevel', 'N/A')}, Temperature: {item.get('temperature', 'N/A')}"
    try:
        sns.publish(TopicArn=topic_arn, Message=message)
        logger.info(f"Alert sent for product {item.get('productId', 'Unknown')}")
    except ClientError as e:
        logger.error(f"Error publishing to SNS: {e}")
