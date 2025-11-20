# Troubleshooting Guide

## Common Issues and Solutions

### Lambda Function Issues

#### Issue: Function not triggered
**Symptoms**: No logs in CloudWatch, instances not tagged
**Causes**:
- EventBridge rule misconfigured
- Lambda permissions missing
- Rule not enabled

**Solutions**:
```bash
# Check EventBridge rule status
aws events describe-rule --name EC2-Instance-Monitor-Rule

# Verify Lambda permissions
aws lambda get-policy --function-name ec2-instance-monitor

# Check rule targets
aws events list-targets-by-rule --rule EC2-Instance-Monitor-Rule
```

#### Issue: KeyError in Lambda logs
**Symptoms**: Function executes but fails with KeyError
**Causes**:
- Event structure mismatch
- Manual function invocation with wrong payload

**Solutions**:
- Check event pattern in EventBridge rule
- Verify Lambda is only triggered by EC2 events
- Test with proper EC2 state change event

### Notification Issues

#### Issue: No email notifications received
**Symptoms**: Alarms trigger but no emails
**Causes**:
- SNS subscription not confirmed
- Email in spam folder
- SNS topic permissions

**Solutions**:
```bash
# Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:REGION:ACCOUNT:EC2-Instance-Limit-Alerts

# Resend confirmation
aws sns subscribe \
  --topic-arn arn:aws:sns:REGION:ACCOUNT:EC2-Instance-Limit-Alerts \
  --protocol email \
  --notification-endpoint your-email@domain.com
```

#### Issue: Duplicate notifications
**Symptoms**: Multiple emails for single violation
**Causes**:
- Multiple alarm triggers
- Lambda function called multiple times

**Solutions**:
- Check alarm evaluation periods
- Review EventBridge rule filters
- Implement idempotency in Lambda function

### Tagging Issues

#### Issue: Instance tags not applied
**Symptoms**: Violations detected but tags missing
**Causes**:
- IAM permissions insufficient
- EC2 API throttling
- Instance in different region

**Solutions**:
```bash
# Verify IAM permissions
aws iam get-role-policy \
  --role-name EC2MonitorRole \
  --policy-name EC2MonitorPolicy

# Check for API throttling in logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/ec2-instance-monitor \
  --filter-pattern "throttl"
```

### Monitoring Issues

#### Issue: CloudWatch metrics missing
**Symptoms**: No data in EC2/GlobalMonitoring namespace
**Causes**:
- CloudWatch permissions missing
- Metric publishing failed
- Wrong namespace or metric name

**Solutions**:
```bash
# List available metrics
aws cloudwatch list-metrics \
  --namespace EC2/GlobalMonitoring

# Check Lambda execution logs
aws logs get-log-events \
  --log-group-name /aws/lambda/ec2-instance-monitor \
  --log-stream-name LATEST_STREAM
```

## Debugging Commands

### Check System Status
```bash
# Verify all components exist
aws lambda get-function --function-name ec2-instance-monitor
aws events describe-rule --name EC2-Instance-Monitor-Rule
aws sns get-topic-attributes --topic-arn arn:aws:sns:REGION:ACCOUNT:EC2-Instance-Limit-Alerts
aws cloudwatch describe-alarms --alarm-names EC2-Instance-Limit-Violation
```

### Monitor Function Execution
```bash
# Get recent invocations
aws lambda get-function --function-name ec2-instance-monitor \
  --query 'Configuration.LastModified'

# Check error rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=ec2-instance-monitor \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Test Function Manually
```bash
# Create test event
cat > test-event.json << EOF
{
  "detail": {
    "instance-id": "i-1234567890abcdef0"
  }
}
EOF

# Invoke function
aws lambda invoke \
  --function-name ec2-instance-monitor \
  --payload file://test-event.json \
  response.json
```

### Validate Instance Tags
```bash
# Find tagged instances
aws ec2 describe-instances \
  --filters "Name=tag:ViolationReason,Values=*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`ViolationReason`].Value|[0]]' \
  --output table
```

## Performance Optimization

### Reduce Lambda Cold Starts
- Keep function warm with CloudWatch Events
- Optimize import statements
- Use provisioned concurrency if needed

### Minimize API Calls
- Cache instance data when possible
- Use pagination for large instance counts
- Implement exponential backoff for retries

### Optimize Costs
- Adjust CloudWatch log retention
- Use appropriate alarm evaluation periods
- Monitor SNS message costs

## Recovery Procedures

### Complete System Recovery
1. Run cleanup script: `./deployment/cleanup.sh`
2. Wait 5 minutes for resource deletion
3. Run deployment script: `./deployment/deploy.sh`
4. Confirm SNS subscription via email

### Partial Component Recovery
```bash
# Recreate Lambda function only
aws lambda delete-function --function-name ec2-instance-monitor
# Then redeploy using deployment script section 2

# Recreate EventBridge rule only
aws events delete-rule --name EC2-Instance-Monitor-Rule
# Then redeploy using deployment script section 3
```

### Data Recovery
- No persistent data stored
- Instance tags remain on EC2 instances
- CloudWatch metrics retained per retention policy
- Redeploy system to resume monitoring
