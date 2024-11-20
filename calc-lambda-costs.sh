#!/bin/bash
# Set your time range (last month)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    START_TIME=$(date -v-1m -v1d -v0H -v0M -v0S +%s)000
    END_TIME=$(date -v-1d -v23H -v59M -v59S +%s)000
else
    # Linux
    START_TIME=$(date -d "$(date +%Y-%m-01) -1 month" +%s)000
    END_TIME=$(date -d "$(date +%Y-%m-01) -1 day 23:59:59" +%s)000
fi

REGION="us-east-1"                                           # Set your AWS region
SPECIFIC_LAMBDA_NAME=""                                      # Variable to store specific Lambda name

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -l|--lambda)
            SPECIFIC_LAMBDA_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-r|--region REGION] [-l|--lambda LAMBDA_NAME]"
            exit 1
            ;;
    esac
done

QUERY='
parse @message /Duration:\s*(?<duration_ms>\d+\.\d+)\s*ms\s*Billed\s*Duration:\s*(?<billed_duration_ms>\d+)\s*ms\s*Memory\s*Size:\s*(?<memory_size_mb>\d+)\s*MB/
| filter @message like /REPORT RequestId/
| stats sum(billed_duration_ms * memory_size_mb * 1.6279296875e-11 + 2.0e-7) as cost_dollars_total by @logStream
'

# Function to execute query and retrieve results
execute_query() {
    local log_group=$1

    # Start query
    QUERY_ID=$(aws logs start-query \
        --log-group-name "$log_group" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --query-string "$QUERY" \
        --region "$REGION" \
        --output text)

    echo "Executing query for log group: $log_group (Query ID: $QUERY_ID)"

    # Wait for query to complete
    while true; do
        STATUS=$(aws logs get-query-results --query-id "$QUERY_ID" --region "$REGION" --output text --query 'status')
        if [[ "$STATUS" == "Complete" ]]; then
            break
        elif [[ "$STATUS" == "Failed" || "$STATUS" == "Cancelled" ]]; then
            echo "Query $QUERY_ID failed or was cancelled."
            return
        fi
        sleep 1
    done

    # Get results
    aws logs get-query-results --query-id "$QUERY_ID" --region "$REGION" \
        --output json | jq -r '.results[] | {LogStream: (.[] | select(.field == "@logStream") | .value), Cost: (.[] | select(.field == "cost_dollars_total") | .value)} | "\(.LogStream)\t\(.Cost)"'
}

# Check for jq installation
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Install it from https://stedolan.github.io/jq/download/"
    exit 1
fi

# Retrieve Lambda log groups
echo "Retrieving Lambda log groups..."
if [[ -n "$SPECIFIC_LAMBDA_NAME" ]]; then
    # If a specific Lambda name is provided, filter for that log group
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/lambda/$SPECIFIC_LAMBDA_NAME" \
        --region "$REGION" \
        --query "logGroups[].logGroupName" \
        --output text)
else
    # Otherwise, retrieve all Lambda log groups
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/lambda/" \
        --region "$REGION" \
        --query "logGroups[].logGroupName" \
        --output text)
fi

# Header for output
printf "%-50s\t%s\n" "FunctionName" "Cost (USD)"
printf "%-50s\t%s\n" "------------" "-----------"

# Iterate over each log group and execute the query
for LOG_GROUP in $LOG_GROUPS; do
    FUNCTION_NAME=$(basename "$LOG_GROUP")
    COST=$(execute_query "$LOG_GROUP" | awk '{sum += $2} END {printf "%.6f", sum}')
    printf "%-50s\t%s\n" "$FUNCTION_NAME" "$COST"
done
