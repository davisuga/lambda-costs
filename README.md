# AWS Lambda Cost Calculator

## Overview

This Bash script helps you calculate the cost of AWS Lambda function executions for a specific month. It uses AWS CloudWatch Logs and the AWS CLI to retrieve and calculate Lambda function costs.

## Prerequisites

- AWS CLI installed and configured
- `jq` JSON processor
- AWS credentials with permissions to:
  - List CloudWatch Log Groups
  - Start and retrieve CloudWatch Logs Insights queries

## Features

- Calculate Lambda function costs for the previous month
- Support for specifying a specific AWS region
- Option to calculate costs for a specific Lambda function
- Cross-platform support (macOS and Linux)

## Usage

### Basic Usage
```bash
./lambda-costs.sh
```
This will calculate costs for all Lambda functions in the default region (us-east-1).

### Optional Parameters
```bash
# Specify a different AWS region
./lambda-costs.sh -r us-west-2

# Calculate costs for a specific Lambda function
./lambda-costs.sh -l my-lambda-function

# Combine region and function name
./lambda-costs.sh -r us-west-2 -l my-lambda-function
```

## How It Works

1. Determines the time range for the previous month
2. Retrieves Lambda log groups
3. Runs a CloudWatch Logs Insights query to calculate costs
4. Calculates total cost based on:
   - Billed duration
   - Memory size
   - AWS Lambda pricing model

## Cost Calculation

The script uses the following formula to estimate Lambda costs:
```
Cost = (Billed Duration * Memory Size * 1.6279296875e-11) + 2.0e-7
```

## Requirements

- Bash
- AWS CLI
- `jq`
- AWS credentials configured

## Installation

1. Clone the repository
2. Make the script executable:
```bash
chmod +x lambda-costs.sh
```
3. Ensure AWS CLI is configured with your credentials

## Limitations

- Provides an estimate of Lambda costs
- Actual billing may vary slightly from this calculation
- Requires AWS CLI and `jq` to be installed

## Contributing

Contributions are welcome! Please submit a pull request or open an issue.

