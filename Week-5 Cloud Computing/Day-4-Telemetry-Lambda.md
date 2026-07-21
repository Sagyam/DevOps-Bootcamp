# Day 4 — Telemetry & Lambda: Watching Everything, Serving Without Servers

> **Today you will:** read metrics, build an alarm that emails you when CPU spikes, ship logs to CloudWatch, find out *who did what* with CloudTrail — then deploy code with **no server at all**: a Lambda function with a public URL, plus an S3-triggered Lambda that reacts to uploads.

---

## 0. Setup

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-south-1
```

---

## Part A — Telemetry (CloudWatch & CloudTrail)

Two planes to watch:
- **CloudWatch** = what your *workloads* are doing (CPU, requests, logs)
- **CloudTrail** = what *people and tools* are doing to your account (every API call: who, what, when, from where)

### A1. Launch a guinea-pig instance

```bash
export AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query 'Parameter.Value' --output text)

aws ec2 create-key-pair --key-name day4-key --key-type ed25519 \
  --query 'KeyMaterial' --output text > day4-key.pem && chmod 400 day4-key.pem

export SG_ID=$(aws ec2 create-security-group --group-name day4-sg \
  --description "ssh only" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID --instance-type t3.micro \
  --key-name day4-key --security-group-ids $SG_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=day4-metrics}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID
export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
```

### A2. Query metrics from the CLI

EC2 publishes CPU, network, and disk metrics automatically. Pull the last hour of CPU:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time   $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average Maximum \
  --output table
```

(Fresh instance = mostly empty; that changes in a minute.)

📝 **The metric vocabulary:** *namespace* (which service), *metric name* (what's measured), *dimensions* (which specific resource), *period* (bucket size), *statistic* (Avg/Max/Sum/p99…). Every CloudWatch question is a combination of these five.

### A3. An alarm that emails you

Alerts flow: **metric → alarm → SNS topic → your inbox**.

```bash
# SNS topic + your email subscription
export TOPIC_ARN=$(aws sns create-topic --name day4-alerts \
  --query 'TopicArn' --output text)

aws sns subscribe --topic-arn $TOPIC_ARN \
  --protocol email \
  --notification-endpoint you@example.com
```

📬 **Check your inbox and click "Confirm subscription" now** — unconfirmed subscriptions receive nothing.

```bash
# Alarm: CPU > 60% for 2 consecutive minutes
aws cloudwatch put-metric-alarm \
  --alarm-name day4-cpu-high-YOURNAME \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 60 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions $TOPIC_ARN
```

Now make the alarm fire — burn some CPU:

```bash
ssh -i day4-key.pem ubuntu@$PUBLIC_IP \
  "sudo apt-get install -y stress-ng >/dev/null 2>&1 && nohup stress-ng --cpu 2 --timeout 300 >/dev/null 2>&1 &"
```

Watch the state flip (takes 2–4 minutes: `INSUFFICIENT_DATA` → `OK` → `ALARM`):

```bash
watch -n 15 "aws cloudwatch describe-alarms \
  --alarm-names day4-cpu-high-YOURNAME \
  --query 'MetricAlarms[0].StateValue' --output text"
```

When it says `ALARM`, check your email. 📧 You've built the smallest possible on-call system.

> 🖥️ **GUI checkpoint:** **CloudWatch → Alarms → your alarm**. The graph shows the metric with your threshold as a red line — watch the CPU spike cross it. Things to explore in the GUI:
> - **Alarm actions** can also trigger **Auto Scaling** or an **EC2 action** (reboot/recover the instance) — self-healing without a human
> - **CloudWatch → Dashboards** — drag-and-drop widgets; every team has a wall-screen dashboard built here
> - The **1-minute vs 5-minute** metric granularity ("detailed monitoring") toggle lives on the EC2 instance's Monitoring tab

### A4. Logs

Metrics say *something is wrong*; logs say *what*. Create a log group and ship a few events by hand to understand the model (group → stream → events):

```bash
aws logs create-log-group --log-group-name /bootcamp/day4
aws logs create-log-stream --log-group-name /bootcamp/day4 --log-stream-name manual-test

aws logs put-log-events \
  --log-group-name /bootcamp/day4 \
  --log-stream-name manual-test \
  --log-events timestamp=$(date +%s000),message="hello from the CLI" \
               timestamp=$(date +%s000),message="ERROR simulated failure in payment service"

# Search across the whole group:
aws logs filter-log-events \
  --log-group-name /bootcamp/day4 \
  --filter-pattern "ERROR" \
  --query 'events[].message'
```

In real systems, the **CloudWatch agent** on EC2 (or FluentBit on EKS) ships logs automatically — same group/stream/event model, no manual `put-log-events`.

> 🖥️ **GUI checkpoint:** **CloudWatch → Logs → Log groups → /bootcamp/day4**:
> - **Retention setting** — column says "Never expire" by default. Click it and set retention (e.g., 30 days). *Unbounded log retention is one of the classic silent AWS bills.*
> - **Logs Insights** (left sidebar) — a SQL-ish query language over your logs; run `fields @timestamp, @message | filter @message like /ERROR/`. This is grep at cloud scale.

### A5. CloudTrail — the audit log

Who terminated that instance last Tuesday? CloudTrail knows. Recent management events are queryable with zero setup:

```bash
# Everything YOU did recently
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=$(aws sts get-caller-identity --query 'Arn' --output text | awk -F/ '{print $NF}') \
  --max-results 10 \
  --query 'Events[].{Time:EventTime,Event:EventName}' --output table

# Every RunInstances call in the account
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances \
  --max-results 5 \
  --query 'Events[].{Time:EventTime,User:Username}' --output table
```

> 🖥️ **GUI checkpoint:** **CloudTrail → Event history**. Click any event and read the raw JSON — source IP, user agent (you can literally see who used the console vs the CLI vs Terraform), request parameters. Note the free event history covers **90 days of management events**; for longer retention or data events (like S3 object reads) you create a **Trail** that writes to an S3 bucket.

Stop the stress test's instance — Part A is done (cleanup of the rest comes at the end):

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

---

## Part B — Lambda

No instance, no container, no cluster. Upload a function; AWS runs it when triggered; you pay per millisecond of execution. Zero traffic = zero cost.

### B1. The execution role

Even serverless code is a *machine identity* — Day 2 rules apply. Lambda needs a role it can assume:

```bash
cat > lambda-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name day4-lambda-role-YOURNAME \
  --assume-role-policy-document file://lambda-trust.json

# Lets the function write its own logs to CloudWatch (connecting Part A!)
aws iam attach-role-policy \
  --role-name day4-lambda-role-YOURNAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### B2. Write, zip, deploy

```bash
mkdir -p lambda-hello && cat > lambda-hello/handler.py <<'EOF'
import json, os, platform

def lambda_handler(event, context):
    print(f"invoked with event: {json.dumps(event)[:200]}")   # -> CloudWatch Logs
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": f"Hello from Lambda, {os.environ.get('STUDENT', 'stranger')}!",
            "python": platform.python_version(),
            "remaining_ms": context.get_remaining_time_in_millis(),
        })
    }
EOF

cd lambda-hello && zip -q function.zip handler.py && cd ..

aws lambda create-function \
  --function-name day4-hello-YOURNAME \
  --runtime python3.13 \
  --handler handler.lambda_handler \
  --zip-file fileb://lambda-hello/function.zip \
  --role arn:aws:iam::$AWS_ACCOUNT_ID:role/day4-lambda-role-YOURNAME \
  --environment "Variables={STUDENT=YOURNAME}" \
  --timeout 10 \
  --memory-size 128
```

(If you get a role-propagation error, wait ~10 seconds and retry — IAM is eventually consistent.)

### B3. Invoke it

```bash
aws lambda invoke \
  --function-name day4-hello-YOURNAME \
  --payload '{"who":"cli"}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

And its logs went straight into CloudWatch — no agent, no config:

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/day4-hello-YOURNAME \
  --query 'events[].message' --output text
```

Notice `START`, your `print()`, `END`, and `REPORT` with billed duration and memory used.

### B4. Give it a public URL

```bash
aws lambda create-function-url-config \
  --function-name day4-hello-YOURNAME \
  --auth-type NONE \
  --query 'FunctionUrl' --output text

aws lambda add-permission \
  --function-name day4-hello-YOURNAME \
  --statement-id public-url \
  --action lambda:InvokeFunctionUrl \
  --principal "*" \
  --function-url-auth-type NONE
```

`curl` the printed URL (or open it in your browser). A live HTTPS endpoint, no servers, and it costs nothing while idle.

> 🖥️ **GUI checkpoint:** **Lambda → Functions → day4-hello-YOURNAME**:
> - **Code** tab — a full in-browser editor; hit **Test** with a sample event and see output inline (great for demos, terrible for teamwork — real code deploys from CI)
> - **Configuration → General configuration** — the **memory slider**: memory also scales CPU proportionally; more memory is often *cheaper* because functions finish faster
> - **Configuration → Environment variables**, **Timeout** (max 15 min), **Concurrency** limits
> - **Monitor** tab — invocations, duration, and error metrics: CloudWatch again, always CloudWatch

### B5. Event-driven: S3 triggers Lambda

The serverless superpower isn't HTTP — it's *reacting to events*. Let's run code on every S3 upload:

```bash
export BUCKET=day4-uploads-YOURNAME
aws s3 mb s3://$BUCKET

mkdir -p lambda-s3 && cat > lambda-s3/handler.py <<'EOF'
def lambda_handler(event, context):
    for rec in event["Records"]:
        b = rec["s3"]["bucket"]["name"]
        k = rec["s3"]["object"]["key"]
        size = rec["s3"]["object"].get("size", "?")
        print(f"NEW OBJECT: s3://{b}/{k} ({size} bytes)")
    return {"processed": len(event["Records"])}
EOF

cd lambda-s3 && zip -q function.zip handler.py && cd ..

aws lambda create-function \
  --function-name day4-s3-watcher-YOURNAME \
  --runtime python3.13 \
  --handler handler.lambda_handler \
  --zip-file fileb://lambda-s3/function.zip \
  --role arn:aws:iam::$AWS_ACCOUNT_ID:role/day4-lambda-role-YOURNAME \
  --timeout 10

# S3 must be allowed to invoke the function…
aws lambda add-permission \
  --function-name day4-s3-watcher-YOURNAME \
  --statement-id s3-invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$BUCKET

# …and the bucket must be told to send events
cat > notification.json <<EOF
{
  "LambdaFunctionConfigurations": [{
    "LambdaFunctionArn": "arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:day4-s3-watcher-YOURNAME",
    "Events": ["s3:ObjectCreated:*"]
  }]
}
EOF

aws s3api put-bucket-notification-configuration \
  --bucket $BUCKET \
  --notification-configuration file://notification.json
```

Trigger it:

```bash
echo "does this wake up the function?" > test-upload.txt
aws s3 cp test-upload.txt s3://$BUCKET/

sleep 5
aws logs filter-log-events \
  --log-group-name /aws/lambda/day4-s3-watcher-YOURNAME \
  --filter-pattern "NEW" \
  --query 'events[].message' --output text
```

Upload → event → function → log, with no polling and no server. This exact pattern powers thumbnail generators, virus scanners, ETL pipelines, and half the internet's file-processing.

---

## 🧹 Cleanup

```bash
# Lambda
aws lambda delete-function --function-name day4-hello-YOURNAME
aws lambda delete-function --function-name day4-s3-watcher-YOURNAME
aws iam detach-role-policy --role-name day4-lambda-role-YOURNAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name day4-lambda-role-YOURNAME

# S3
aws s3 rm s3://$BUCKET --recursive
aws s3 rb s3://$BUCKET

# Telemetry
aws cloudwatch delete-alarms --alarm-names day4-cpu-high-YOURNAME
aws sns delete-topic --topic-arn $TOPIC_ARN
aws logs delete-log-group --log-group-name /bootcamp/day4
aws logs delete-log-group --log-group-name /aws/lambda/day4-hello-YOURNAME
aws logs delete-log-group --log-group-name /aws/lambda/day4-s3-watcher-YOURNAME

# EC2 leftovers
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name day4-key

rm -rf lambda-hello lambda-s3
rm -f day4-key.pem lambda-trust.json notification.json response.json test-upload.txt
```

---

## ✅ Day 4 Checklist

- [ ] Queried CloudWatch metrics with namespace/dimension/period/statistic
- [ ] Built a metric → alarm → SNS → email pipeline and made it fire
- [ ] Understood log groups/streams/events; searched with filter patterns
- [ ] Used CloudTrail to answer "who did what, when, from where"
- [ ] Deployed a Lambda with an execution role, env vars, and a public URL
- [ ] Read a function's auto-generated CloudWatch logs (incl. the REPORT line)
- [ ] Wired an S3 → Lambda event trigger and proved it fires
- [ ] Cleaned up everything

## 🏠 Homework

1. Modify the S3-watcher so it *rejects* large files: if the uploaded object is bigger than 1 KB, log a `WARNING` line instead. Prove it with two uploads and a Logs Insights query.
2. Your podinfo service from Day 3 goes down at 3 AM. Using only today's tools, design the alerting that would have woken someone up: which metric, which threshold, which alarm settings, and why.
