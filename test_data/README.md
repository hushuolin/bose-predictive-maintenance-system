# Test Data for Bose Predictive Maintenance System

## Introduction
This folder contains test data files used to validate the functionality of the Bose Predictive Maintenance System data pipeline. These files are designed to cover various scenarios, including normal operation, edge cases, and error conditions. The tests are intended to validate the interaction between Amazon S3, AWS Lambda, DynamoDB, and SNS.

## Test Cases Description

1. **`01_normal_data.json`**: 
   - Contains valid health data for typical devices with no anomalies. Used to test standard data processing.

2. **`02_low_battery.json`**: 
   - Tests the scenario where the battery level is below the threshold of `0.1`. The expected behavior is to trigger an SNS alert.

3. **`03_high_temperature.json`**: 
   - Contains data with temperature values above `50°C` to verify that the system correctly triggers an alert.

4. **`04_missing_fields.json`**: 
   - Tests missing mandatory fields like `productId`. The Lambda function should log an error without crashing.

5. **`05_invalid_data.json`**: 
   - Tests invalid data types (e.g., battery level as a string). The Lambda function should handle these gracefully by logging errors.

6. **`06_large_dataset.json`**: 
   - Contains multiple records to test batch processing capabilities. This helps validate that the Lambda function can efficiently process larger payloads.

7. **`07_high_precision_data.json`**: 
   - Contains high-precision float values to ensure that the system handles precision correctly using Decimal types in DynamoDB.

8. **`08_invalid_timestamp.json`**: 
   - Tests how the Lambda function handles an invalid timestamp value. It should log an error without processing the invalid record.

## Usage Instructions
- **Manual Testing**:
  - Upload each test file to the S3 bucket configured for health data ingestion using the AWS Console or the following CLI command:
    ```sh
    aws s3 cp <file_name> s3://<your-health-data-bucket-name> --region <your-region>
    ```
- **Automated Testing**:
  - You can use a script to automate the uploading of test files to S3 for repeated testing scenarios.

### Expected Behavior
- **Lambda Execution Logs**: The Lambda function should log each step of the process in CloudWatch Logs.
- **DynamoDB Table**: Records should be successfully added to the `BoseHealthMetricsTable` for valid data.
- **SNS Alerts**: For data with anomalies (e.g., low battery or high temperature), an SNS alert should be sent.

## Data Format
- Each test data file is a JSON array of health metrics.
- Fields include:
  - **`productId`**: (string) Unique identifier of the device.
  - **`batteryLevel`**: (Decimal) Battery level of the device.
  - **`temperature`**: (Decimal) Temperature reading in degrees Celsius.
  - **`timestamp`**: (int) UNIX timestamp representing when the data was recorded.

## Best Practices
- Add new test cases to cover any additional scenarios introduced in the system.
- Follow the naming convention (`<number>_<description>.json`) when adding new files for clarity and consistency.
