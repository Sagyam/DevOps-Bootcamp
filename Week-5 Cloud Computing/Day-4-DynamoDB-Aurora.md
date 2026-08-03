# Day 4 — DynamoDB & Aurora: Two Databases, Two Philosophies

> **Today you will:** build a NoSQL table in DynamoDB (keys, queries, indexes, TTL) and a real relational cluster in Aurora Serverless v2 (MySQL-compatible), connect to both, and understand *when to reach for which*.

The core contrast of the day:

| | **DynamoDB** | **Aurora** |
|---|---|---|
| Model | Key-value / document (NoSQL) | Relational (MySQL/PostgreSQL wire-compatible) |
| Schema | Only the keys are fixed | Full schema, enforced |
| Query language | API calls (`query`, `scan`) / PartiQL | SQL, joins, transactions |
| Scaling | Automatic, effectively unlimited | Vertical + read replicas (Serverless v2 auto-scales capacity) |
| Ops burden | Zero servers, zero patching | Managed, but still a *cluster* you configure |
| Sweet spot | Sessions, carts, IoT, anything key-shaped at scale | Anything with relationships, reporting, ad-hoc queries |

💸 **Cost warning:** DynamoDB on-demand is pennies today. Aurora bills while the cluster exists — **deleting it at the end is mandatory.**

---

## 0. Setup

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-south-1
```

---

## Part A — DynamoDB

We'll model something you know: **shortened links** from the ShortLink capstone.

### A1. Create a table

The only schema DynamoDB wants is the key design. We use a composite key: **partition key** `user_id` (which "bucket" the item lands in) + **sort key** `short_code` (ordering within the bucket):

```bash
aws dynamodb create-table \
  --table-name shortlinks-YOURNAME \
  --attribute-definitions \
      AttributeName=user_id,AttributeType=S \
      AttributeName=short_code,AttributeType=S \
  --key-schema \
      AttributeName=user_id,KeyType=HASH \
      AttributeName=short_code,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

aws dynamodb wait table-exists --table-name shortlinks-YOURNAME
```

📝 `PAY_PER_REQUEST` (on-demand) = pay per read/write, no capacity planning. The alternative, `PROVISIONED`, pre-buys read/write capacity units — cheaper at steady high volume, but *you* do the capacity math.

### A2. Write items

Items are JSON with typed values (`S` string, `N` number, `BOOL`, `L` list, `M` map). Attributes beyond the keys can differ per item — that's the "schemaless" part:

```bash
aws dynamodb put-item --table-name shortlinks-YOURNAME --item '{
  "user_id":   {"S": "alice"},
  "short_code":{"S": "gh1"},
  "target_url":{"S": "https://github.com"},
  "clicks":    {"N": "0"},
  "created":   {"S": "2026-07-20"}
}'

aws dynamodb put-item --table-name shortlinks-YOURNAME --item '{
  "user_id":   {"S": "alice"},
  "short_code":{"S": "k8s"},
  "target_url":{"S": "https://kubernetes.io"},
  "clicks":    {"N": "0"},
  "tags":      {"L": [{"S":"docs"},{"S":"work"}]}
}'

aws dynamodb put-item --table-name shortlinks-YOURNAME --item '{
  "user_id":   {"S": "bob"},
  "short_code":{"S": "np"},
  "target_url":{"S": "https://blog.sagyamthapa.com.np"},
  "clicks":    {"N": "42"}
}'
```

### A3. Read: get, query, scan — and why the difference matters

```bash
# get-item: exact key, single item, fastest possible
aws dynamodb get-item --table-name shortlinks-YOURNAME \
  --key '{"user_id":{"S":"alice"},"short_code":{"S":"gh1"}}'

# query: one partition, optionally filtered by sort key — fast, cheap
aws dynamodb query --table-name shortlinks-YOURNAME \
  --key-condition-expression "user_id = :u" \
  --expression-attribute-values '{":u":{"S":"alice"}}' \
  --query 'Items[].{code:short_code.S,url:target_url.S}' --output table

# scan: reads THE ENTIRE TABLE — fine for 3 items, a disaster for 3 billion
aws dynamodb scan --table-name shortlinks-YOURNAME \
  --query 'Count'
```

⚠️ **The rule that separates DynamoDB professionals from tourists:** if your access pattern needs a `scan` in production, your key design is wrong. Design tables around *queries you will make*, not around the data's shape.

### A4. Update atomically

Increment a click counter without read-modify-write races:

```bash
aws dynamodb update-item --table-name shortlinks-YOURNAME \
  --key '{"user_id":{"S":"bob"},"short_code":{"S":"np"}}' \
  --update-expression "SET clicks = clicks + :one" \
  --expression-attribute-values '{":one":{"N":"1"}}' \
  --return-values UPDATED_NEW
```

Run it three times — the counter climbs. A thousand concurrent Lambdas could run this safely.

### A5. A Global Secondary Index — querying a different question

Current keys answer "give me *alice's* links". They cannot answer "which link is `np`, regardless of owner". A **GSI** re-keys the same data:

```bash
aws dynamodb update-table \
  --table-name shortlinks-YOURNAME \
  --attribute-definitions AttributeName=short_code,AttributeType=S \
  --global-secondary-index-updates '[{
    "Create": {
      "IndexName": "by-code",
      "KeySchema": [{"AttributeName":"short_code","KeyType":"HASH"}],
      "Projection": {"ProjectionType":"ALL"}
    }
  }]'
```

Wait for the index to backfill (~1–2 min), then query it:

```bash
watch -n 10 "aws dynamodb describe-table --table-name shortlinks-YOURNAME \
  --query 'Table.GlobalSecondaryIndexes[0].IndexStatus' --output text"
# Ctrl-C when ACTIVE

aws dynamodb query --table-name shortlinks-YOURNAME \
  --index-name by-code \
  --key-condition-expression "short_code = :c" \
  --expression-attribute-values '{":c":{"S":"np"}}' \
  --query 'Items[].{owner:user_id.S,url:target_url.S}' --output table
```

That's the resolver query your ShortLink redirect endpoint would actually run.

### A6. TTL — items that delete themselves

Perfect for sessions and temporary links:

```bash
aws dynamodb update-time-to-live \
  --table-name shortlinks-YOURNAME \
  --time-to-live-specification "Enabled=true,AttributeName=expires_at"

# An item that self-destructs in ~10 minutes (TTL uses epoch seconds)
aws dynamodb put-item --table-name shortlinks-YOURNAME --item '{
  "user_id":   {"S": "alice"},
  "short_code":{"S": "tmp"},
  "target_url":{"S": "https://example.com/one-time-offer"},
  "expires_at":{"N": "'$(date -d '+10 minutes' +%s)'"}
}'
```

(Actual deletion happens within ~48h of expiry — TTL is a janitor, not a scheduler.)

> 🖥️ **GUI checkpoint:** **DynamoDB → Tables → shortlinks-YOURNAME**:
> - **Explore table items** — a spreadsheet-like item browser with point-and-click query/scan builder; also runs **PartiQL** (SQL-ish syntax over DynamoDB)
> - **Indexes** tab — your GSI and its own capacity
> - **Additional settings** — where **Point-in-time recovery** (continuous backups, 35-day rewind) and **DynamoDB Streams** (change events → Lambda, the Day 4 pattern again) are switched on
> - **Monitor** tab — throttled request metrics: the graph you check when the app screams `ProvisionedThroughputExceededException`

---

## Part B — Aurora

Aurora is AWS's cloud-native re-engineering of MySQL/PostgreSQL: same wire protocol your apps already speak, but storage is a distributed layer replicating **6 ways across 3 AZs**. We'll use **Serverless v2**, which scales capacity (measured in **ACUs**) up and down automatically.

### B1. Network prerequisites

A database cluster lives inside a VPC and needs its own security group. We'll use the default VPC:

```bash
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)

export DB_SG=$(aws ec2 create-security-group \
  --group-name day5-db-sg-YOURNAME \
  --description "MySQL from within the VPC" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# MySQL port 3306, only from inside this VPC — databases NEVER face the internet
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG \
  --protocol tcp --port 3306 \
  --cidr $(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock' --output text)
```

### B2. Create the cluster

An Aurora deployment = one **cluster** (the storage + endpoints) + one or more **instances** (the compute that serves queries):

```bash
aws rds create-db-cluster \
  --db-cluster-identifier day5-aurora-YOURNAME \
  --engine aurora-mysql \
  --engine-version 8.0.mysql_aurora.3.08.0 \
  --master-username admin \
  --master-user-password 'Bootcamp2026!' \
  --vpc-security-group-ids $DB_SG \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=2 \
  --backup-retention-period 1

aws rds create-db-instance \
  --db-instance-identifier day5-aurora-YOURNAME-1 \
  --db-cluster-identifier day5-aurora-YOURNAME \
  --db-instance-class db.serverless \
  --engine aurora-mysql
```

⏱️ Takes ~10 minutes. Wait:

```bash
aws rds wait db-instance-available --db-instance-identifier day5-aurora-YOURNAME-1
```

Grab the endpoints:

```bash
aws rds describe-db-clusters --db-cluster-identifier day5-aurora-YOURNAME \
  --query 'DBClusters[0].{Writer:Endpoint,Reader:ReaderEndpoint}' --output table

export DB_HOST=$(aws rds describe-db-clusters \
  --db-cluster-identifier day5-aurora-YOURNAME \
  --query 'DBClusters[0].Endpoint' --output text)
```

📝 **Two endpoints, one habit:** apps send writes to the **writer endpoint** and reads to the **reader endpoint**. Add read replicas later and the reader endpoint load-balances across them — the app never changes.

> 🖥️ **GUI checkpoint:** **RDS → Databases → day5-aurora-YOURNAME**. The console shows the cluster with its instance nested under it. Worth touring:
> - **Modify** → the **Serverless v2 capacity range** slider (our 0.5–2 ACUs) — this is the knob that caps both performance *and* cost
> - **Maintenance & backups** tab — backup retention, **backtrack** (rewind the cluster in place!), and the maintenance window
> - **Connectivity & security** — note **Public access: No**; also where you'd enable **IAM database authentication** (log in to MySQL with IAM tokens instead of passwords — the Day 2 philosophy invading the database)
> - **Add reader** action — one click adds a read replica served by the same storage layer, usually in seconds

### B3. Connect and use SQL

The cluster is VPC-internal, so we connect from a small EC2 instance in the same VPC (the same way your app servers would):

```bash
export AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query 'Parameter.Value' --output text)

aws ec2 create-key-pair --key-name day5-key --key-type ed25519 \
  --query 'KeyMaterial' --output text > day5-key.pem && chmod 400 day5-key.pem

export SG_ID=$(aws ec2 create-security-group --group-name day5-client-sg \
  --description "ssh" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID --instance-type t3.micro \
  --key-name day5-key --security-group-ids $SG_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=day5-db-client}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID
export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

ssh -i day5-key.pem ubuntu@$PUBLIC_IP
```

Inside the instance (replace `DB_HOST` with the writer endpoint you printed):

```bash
sudo apt-get update -y && sudo apt-get install -y mysql-client

mysql -h DB_HOST -u admin -p'Bootcamp2026!'
```

You're in a MySQL shell — everything from here is plain SQL:

```sql
CREATE DATABASE shortlink;
USE shortlink;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE links (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  short_code VARCHAR(16) UNIQUE NOT NULL,
  target_url TEXT NOT NULL,
  clicks INT DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO users (username) VALUES ('alice'), ('bob');
INSERT INTO links (user_id, short_code, target_url, clicks) VALUES
  (1, 'gh1', 'https://github.com', 0),
  (1, 'k8s', 'https://kubernetes.io', 0),
  (2, 'np',  'https://blog.sagyamthapa.com.np', 42);

-- The thing DynamoDB cannot do without redesigning the table: an ad-hoc JOIN
SELECT u.username, COUNT(*) AS links, SUM(l.clicks) AS total_clicks
FROM users u JOIN links l ON l.user_id = u.id
GROUP BY u.username;

-- And a transaction: all-or-nothing
START TRANSACTION;
UPDATE links SET clicks = clicks + 1 WHERE short_code = 'np';
INSERT INTO links (user_id, short_code, target_url) VALUES (2, 'aws', 'https://aws.amazon.com');
COMMIT;

SELECT short_code, clicks FROM links;
EXIT;
```

```bash
exit   # leave the EC2 instance
```

### B4. The takeaway question

Same ShortLink data lived in both databases today. Reflect:

- The **redirect** hot path (`short_code → url`, millions/sec, key-shaped) → DynamoDB's GSI answered it in single-digit ms with zero servers.
- The **analytics** question ("links and total clicks per user") → one line of SQL in Aurora; in DynamoDB it would need a scan or a redesigned table.

Real systems frequently use **both**: DynamoDB on the hot path, a relational store for everything with relationships. Choosing *per workload*, not *per fashion*, is the skill.

---

## 🧹 Cleanup (Aurora bills by the hour — do this now)

```bash
# Client instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name day5-key && rm -f day5-key.pem

# Aurora: instance first, then cluster (skip final snapshot — it's a lab)
aws rds delete-db-instance \
  --db-instance-identifier day5-aurora-YOURNAME-1 \
  --skip-final-snapshot
aws rds wait db-instance-deleted --db-instance-identifier day5-aurora-YOURNAME-1

aws rds delete-db-cluster \
  --db-cluster-identifier day5-aurora-YOURNAME \
  --skip-final-snapshot

# DB security group (wait for cluster deletion to release it; retry if it complains)
sleep 60 && aws ec2 delete-security-group --group-id $DB_SG

# DynamoDB
aws dynamodb delete-table --table-name shortlinks-YOURNAME
```

Verify:

```bash
aws rds describe-db-clusters --query 'DBClusters[].DBClusterIdentifier' --output table
aws dynamodb list-tables --output table
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output table
```

---

## ✅ Day 5 Checklist

- [ ] Created a DynamoDB table with a composite key, on-demand billing
- [ ] Used get vs query vs scan — and can explain when each is a mistake
- [ ] Performed an atomic counter update
- [ ] Added a GSI and queried the data by a different key
- [ ] Enabled TTL for self-expiring items
- [ ] Created an Aurora Serverless v2 cluster with a VPC-only security group
- [ ] Connected via a client instance; used schemas, JOINs, and transactions
- [ ] Can articulate the DynamoDB-vs-relational decision for a given workload
- [ ] Deleted the cluster (and everything else)

## 🏠 Homework

1. Design the DynamoDB key schema for a **URL click log** (every click is an item, and the top query is "all clicks for a short_code in a time range"). Give the partition key, sort key, and the exact `query` command.
2. For each, pick DynamoDB or Aurora and defend it in two sentences: (a) a shopping-cart service, (b) monthly revenue reports for the finance team, (c) storing IoT sensor readings at 50k writes/sec, (d) a student-records system with enrolment rules.
