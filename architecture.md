# Architecture Documentation

## System Overview

The EC2 Global Instance Limit Monitor is built using AWS serverless services to provide real-time monitoring and alerting for EC2 instance counts across an AWS account.

## Component Details

### EventBridge Rule
- **Purpose**: Captures EC2 instance state change events
- **Filter**: Only processes instances transitioning to "running" state
- **Trigger**: Invokes Lambda function for each qualifying event

### Lambda Function
- **Runtime**: Python 3.9
- **Memory**: 128MB
- **Timeout**: 60 seconds
- **Execution Model**: Synchronous invocation from EventBridge

### CloudWatch Integration
- **Metrics**: Custom namespace `EC2/GlobalMonitoring`
- **Alarms**: Dual alarm strategy for comprehensive monitoring
- **Logs**: Centralized logging for debugging and audit

### SNS Notification
- **Topic**: Dedicated topic for EC2 limit alerts
- **Delivery**: Email notifications with detailed violation information
- **Reliability**: Built-in retry and dead letter queue support

## Data Flow

```
1. EC2 Instance Launch
   ↓
2. AWS generates state change event
   ↓
3. EventBridge captures event (state = "running")
   ↓
4. Lambda function triggered
   ↓
5. Query all running instances via EC2 API
   ↓
6. Count instances (excluding current)
   ↓
7. Check against limit (12 instances)
   ↓
8a. If under limit: Send count metric only
8b. If over limit: Tag instance + Send violation metric + SNS notification
   ↓
9. CloudWatch processes metrics
   ↓
10. Alarms evaluate thresholds
   ↓
11. Additional SNS notifications if alarm triggered
```

## Security Model

### IAM Permissions
- **Principle**: Least privilege access
- **EC2**: Read instances, create tags only
- **CloudWatch**: Metric publishing only
- **SNS**: Publish to specific topic only
- **Logs**: Standard Lambda logging permissions

### Network Security
- **Lambda**: Runs in AWS managed VPC
- **Encryption**: All data in transit encrypted
- **API Calls**: Authenticated via IAM roles

## Scalability Considerations

### Performance
- **Concurrent Executions**: Supports multiple simultaneous instance launches
- **API Rate Limits**: EC2 DescribeInstances has high default limits
- **Processing Time**: Typically completes in <5 seconds

### Limitations
- **Region Scope**: Monitors single region per deployment
- **Account Scope**: Single AWS account monitoring
- **Instance Limit**: Configurable, currently set to 12

## Monitoring and Observability

### Metrics Available
- `ViolationStatus`: Binary indicator (0/1)
- `TotalInstanceCount`: Current running instance count
- Lambda standard metrics (duration, errors, invocations)

### Logging Strategy
- **Lambda Logs**: Execution details and errors
- **CloudWatch Logs**: Centralized log aggregation
- **Retention**: Configurable log retention period

### Alerting Layers
1. **Instance Tagging**: Immediate identification
2. **CloudWatch Metrics**: Historical tracking
3. **CloudWatch Alarms**: Threshold-based alerting
4. **SNS Notifications**: Human notification

## Disaster Recovery

### Backup Strategy
- **Infrastructure as Code**: All resources defined in scripts
- **Configuration**: Stored in version control
- **State**: Stateless design, no data persistence required

### Recovery Procedures
- **Redeploy**: Use deployment scripts for full recreation
- **Partial Recovery**: Individual component recreation possible
- **Data Loss**: No persistent data, minimal impact

## Cost Optimization

### Resource Efficiency
- **Serverless**: Pay-per-use model
- **Right-sizing**: Minimal Lambda memory allocation
- **Retention**: Optimized log retention periods

### Cost Monitoring
- **Monthly Estimate**: <$10 for typical usage
- **Variable Costs**: Scale with instance launch frequency
- **Fixed Costs**: CloudWatch alarms and SNS topic
