import json
import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

def handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        # Get the file from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        file_content = response['Body'].read().decode('utf-8')
        health_data = json.loads(file_content)
        
        # Process and store the health data
        process_health_data(health_data)
    
    return {'statusCode': 200, 'body': 'Health data processed successfully'}

def process_health_data(health_data):
    table = dynamodb.Table(os.environ['HEALTH_METRICS_TABLE'])
    alert_topic_arn = os.environ['ALERT_TOPIC_ARN']
    
    for item in health_data:
        # Store in DynamoDB
        table.put_item(Item=item)
        
        # Check for anomalies and send alert if necessary
        if check_for_anomalies(item):
            send_alert(item, alert_topic_arn)

def check_for_anomalies(item):
    # Implement your anomaly detection logic here
    # For example, check if battery level is too low or temperature is too high
    return item['batteryLevel'] < 0.1 or item['temperature'] > 50

def send_alert(item, topic_arn):
    message = f"Alert for product {item['productId']}: Battery level: {item['batteryLevel']}, Temperature: {item['temperature']}"
    sns.publish(TopicArn=topic_arn, Message=message)
