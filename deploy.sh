#!/bin/bash

# EC2 Instance Monitor Deployment Script
set -e

# Configuration
REGION=${AWS_REGION:-us-west-2}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EMAIL=${NOTIFICATION_EMAIL:-admin@example.com}

echo "🚀 Deploying EC2 Instance Monitor..."
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo "Email: $EMAIL"

# 1. Create IAM Role
echo "📋 Creating IAM Role..."
aws iam create-role \
  --role-name EC2MonitorRole \
  --assume-role-policy-document file://trust-policy.json \
  --region $REGION

aws iam put-role-policy \
  --role-name EC2MonitorRole \
  --policy-name EC2MonitorPolicy \
  --policy-document file://permissions-policy.json \
  --region $REGION

# Wait for role propagation
sleep 10

# 2. Create Lambda Function
echo "⚡ Creating Lambda Function..."
zip lambda_function.zip lambda_function.py

aws lambda create-function \
  --function-name ec2-instance-monitor \
  --runtime python3.9 \
  --role arn:aws:iam::$ACCOUNT_ID:role/EC2MonitorRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --description "Monitor EC2 instance count and send alerts when limit exceeded" \
  --region $REGION

# 3. Create EventBridge Rule
echo "📅 Creating EventBridge Rule..."
aws events put-rule \
  --name EC2-Instance-Monitor-Rule \
  --event-pattern file://event-pattern.json \
  --description "Trigger Lambda when EC2 instances enter running state" \
  --region $REGION

aws events put-targets \
  --rule EC2-Instance-Monitor-Rule \
  --targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:ec2-instance-monitor" \
  --region $REGION

# Add Lambda permission for EventBridge
aws lambda add-permission \
  --function-name ec2-instance-monitor \
  --statement-id allow-eventbridge \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:$REGION:$ACCOUNT_ID:rule/EC2-Instance-Monitor-Rule \
  --region $REGION

# 4. Create SNS Topic and Subscription
echo "📧 Creating SNS Topic..."
aws sns create-topic \
  --name EC2-Instance-Limit-Alerts \
  --region $REGION

aws sns subscribe \
  --topic-arn arn:aws:sns:$REGION:$ACCOUNT_ID:EC2-Instance-Limit-Alerts \
  --protocol email \
  --notification-endpoint $EMAIL \
  --region $REGION

# 5. Create CloudWatch Alarms
echo "⏰ Creating CloudWatch Alarms..."
aws cloudwatch put-metric-alarm \
  --alarm-name EC2-Instance-Limit-Violation \
  --alarm-description "Alert when EC2 instances exceed global limit" \
  --metric-name ViolationStatus \
  --namespace EC2/GlobalMonitoring \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:$REGION:$ACCOUNT_ID:EC2-Instance-Limit-Alerts \
  --region $REGION

aws cloudwatch put-metric-alarm \
  --alarm-name EC2-Total-Instance-Count-Exceeded \
  --alarm-description "Alert when total EC2 instances exceed 12" \
  --metric-name TotalInstanceCount \
  --namespace EC2/GlobalMonitoring \
  --statistic Maximum \
  --period 300 \
  --threshold 12 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:$REGION:$ACCOUNT_ID:EC2-Instance-Limit-Alerts \
  --region $REGION

echo "✅ Deployment completed successfully!"
echo "📧 Please check your email ($EMAIL) and confirm the SNS subscription."
echo "🔍 Monitor the system at: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"
