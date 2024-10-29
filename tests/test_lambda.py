import unittest
from unittest.mock import patch, MagicMock
from lambda import index

class TestLambdaFunction(unittest.TestCase):
    @patch('lambda.index.s3')
    @patch('lambda.index.dynamodb')
    @patch('lambda.index.sns')
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

        # Call the handler
        response = index.handler(event, context)

        # Assert the response
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(response['body'], 'Health data processed successfully')

        # Add more assertions as needed to verify the behavior of your function

if __name__ == '__main__':
    unittest.main()
