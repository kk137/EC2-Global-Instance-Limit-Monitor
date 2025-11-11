#!/bin/bash

# EC2 Instance Monitor Cleanup Script
set -e

# Configuration
REGION=${AWS_REGION:-us-west-2}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🧹 Cleaning up EC2 Instance Monitor..."
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"

# 1. Delete CloudWatch Alarms
echo "⏰ Deleting CloudWatch Alarms..."
aws cloudwatch delete-alarms \
  --alarm-names EC2-Instance-Limit-Violation EC2-Total-Instance-Count-Exceeded \
  --region $REGION || true

# 2. Delete SNS Topic
echo "📧 Deleting SNS Topic..."
aws sns delete-topic \
  --topic-arn arn:aws:sns:$REGION:$ACCOUNT_ID:EC2-Instance-Limit-Alerts \
  --region $REGION || true

# 3. Delete EventBridge Rule
echo "📅 Deleting EventBridge Rule..."
aws events remove-targets \
  --rule EC2-Instance-Monitor-Rule \
  --ids "1" \
  --region $REGION || true

aws events delete-rule \
  --name EC2-Instance-Monitor-Rule \
  --region $REGION || true

# 4. Delete Lambda Function
echo "⚡ Deleting Lambda Function..."
aws lambda delete-function \
  --function-name ec2-instance-monitor \
  --region $REGION || true

# 5. Delete IAM Role and Policies
echo "📋 Deleting IAM Role..."
aws iam delete-role-policy \
  --role-name EC2MonitorRole \
  --policy-name EC2MonitorPolicy || true

aws iam delete-role-policy \
  --role-name EC2MonitorRole \
  --policy-name SNSPublishPolicy || true

aws iam delete-role \
  --role-name EC2MonitorRole || true

# 6. Clean up local files
echo "🗑️ Cleaning up local files..."
rm -f lambda_function.zip

echo "✅ Cleanup completed successfully!"
echo "🏷️ Note: Instance tags added by the monitor will remain on existing instances."
