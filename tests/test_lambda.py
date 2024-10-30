import unittest
from unittest.mock import patch, MagicMock
import json
import os
from lambda_functions.index import handler

@patch.dict(os.environ, {"HEALTH_METRICS_TABLE": "test-health-metrics-table", "ALERT_TOPIC_ARN": "arn:aws:sns:us-west-2:123456789012:test-topic"})
class TestLambdaFunction(unittest.TestCase):
    @patch('lambda_functions.index.s3')
    @patch('lambda_functions.index.dynamodb')
    @patch('lambda_functions.index.sns')
    def test_handler(self, mock_sns, mock_dynamodb, mock_s3):
        # Set up your test event and context
        event = {
            'Records': [
                {
                    's3': {
                        'bucket': {'name': 'test-bucket'},
                        'object': {'key': 'test-key'}
                    }
                }
            ]
        }
        context = {}

        # Mock the S3 get_object response
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: json.dumps([
                {
                    'productId': 'test-product',
                    'batteryLevel': 0.5,
                    'temperature': 25
                }
            ]).encode('utf-8'))
        }

        # Mock DynamoDB Table
        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table

        # Call the handler
        response = handler(event, context)

        # Assert the response
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(response['body'], 'Health data processed successfully')

        # Verify S3 get_object was called
        mock_s3.get_object.assert_called_once_with(Bucket='test-bucket', Key='test-key')

        # Verify DynamoDB put_item was called
        mock_table.put_item.assert_called_once()
        put_item_args = mock_table.put_item.call_args[1]
        self.assertEqual(put_item_args['Item']['productId'], 'test-product')
        self.assertEqual(put_item_args['Item']['batteryLevel'], 0.5)
        self.assertEqual(put_item_args['Item']['temperature'], 25)

        # Verify SNS publish was not called (no anomaly in this test case)
        mock_sns.publish.assert_not_called()

    @patch('lambda_functions.index.s3')
    @patch('lambda_functions.index.dynamodb')
    @patch('lambda_functions.index.sns')
    def test_handler_with_anomaly(self, mock_sns, mock_dynamodb, mock_s3):
        # Set up your test event and context
        event = {
            'Records': [
                {
                    's3': {
                        'bucket': {'name': 'test-bucket'},
                        'object': {'key': 'test-key'}
                    }
                }
            ]
        }
        context = {}

        # Mock the S3 get_object response with anomalous data
        mock_s3.get_object.return_value = {
            'Body': MagicMock(read=lambda: json.dumps([
                {
                    'productId': 'test-product',
                    'batteryLevel': 0.05,
                    'temperature': 55
                }
            ]).encode('utf-8'))
        }

        # Mock DynamoDB Table
        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table

        # Mock SNS publish
        mock_sns.publish = MagicMock()

        # Call the handler
        response = handler(event, context)

        # Assert the response
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(response['body'], 'Health data processed successfully')

        # Verify S3 get_object was called
        mock_s3.get_object.assert_called_once_with(Bucket='test-bucket', Key='test-key')

        # Verify DynamoDB put_item was called
        mock_table.put_item.assert_called_once()

        # Verify SNS publish was called
        mock_sns.publish.assert_called_once()
        publish_args = mock_sns.publish.call_args[1]
        self.assertIn('test-product', publish_args['Message'])
        self.assertIn('0.05', publish_args['Message'])
        self.assertIn('55', publish_args['Message'])

if __name__ == '__main__':
    unittest.main()
