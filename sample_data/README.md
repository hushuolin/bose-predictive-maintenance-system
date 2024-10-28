# Sample Health Data for Bose Predictive Maintenance System

This directory contains sample data files used for development and testing of the Bose Predictive Maintenance System.

## File: sample_health_data.json

This file contains an array of JSON objects, each representing a health data point from a Bose product.

### Data Structure

Each object in the array has the following structure:

| Field           | Type    | Description                                                  |
|-----------------|---------|--------------------------------------------------------------|
| productId       | string  | Unique identifier for the Bose product                       |
| timestamp       | number  | Unix timestamp when the data was recorded                    |
| batteryLevel    | number  | Battery level as a decimal (0.0 to 1.0), null if not applicable |
| temperature     | number  | Internal temperature of the device in Celsius                |
| usageHours      | number  | Total hours the device has been in use                       |
| firmwareVersion | string  | Current version of the device's firmware                     |
| errorCode       | string  | Error code reported by the device, null if no errors         |

### Sample Record

```json
{
  "productId": "BOSE-SPEAKER-001",
  "timestamp": 1623456789,
  "batteryLevel": 0.75,
  "temperature": 35.5,
  "usageHours": 120,
  "firmwareVersion": "2.1.0",
  "errorCode": null
}
