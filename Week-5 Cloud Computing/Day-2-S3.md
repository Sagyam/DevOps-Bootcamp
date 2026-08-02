# Day 2 —  S3: Where Everything Lives

> **Today you will:** create users, groups, and policies; watch an `AccessDenied` turn into an `Allow`; give a *machine* permissions with a role (no passwords involved); then master S3 — buckets, versioning, lifecycle rules, presigned URLs, and a static website.

---

## 0. Setup

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-south-1
```

## S3

### 1. Create a bucket

Bucket names are globally unique — use your name:

```bash
export BUCKET=bootcamp-YOURNAME-site

aws s3 mb s3://$BUCKET --region $AWS_REGION
```

### 2. Upload things

The CLI has two S3 layers: `aws s3` (friendly, rsync-like) and `aws s3api` (raw API, one flag per parameter). Use the first daily, the second when you need precision.

```bash
# Single file
echo "<h1>Hello S3 from YOURNAME</h1>" > index.html
echo "<h1>404 — not here, friend</h1>" > error.html
aws s3 cp index.html s3://$BUCKET/
aws s3 cp error.html s3://$BUCKET/

# A whole directory, rsync-style (only changed files transfer)
mkdir -p assets && echo "body { font-family: monospace; }" > assets/style.css
aws s3 sync assets/ s3://$BUCKET/assets/

# List
aws s3 ls s3://$BUCKET/ --recursive --human-readable
```

### 3. Versioning — the undo button

```bash
aws s3api put-bucket-versioning \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled
```

Overwrite the file, then discover both versions still exist:

```bash
echo "<h1>Version 2 — improved!</h1>" > index.html
aws s3 cp index.html s3://$BUCKET/

aws s3api list-object-versions --bucket $BUCKET \
  --prefix index.html \
  --query 'Versions[].{VersionId:VersionId,IsLatest:IsLatest,Modified:LastModified}' \
  --output table
```

Even a **delete** is just a marker on top:

```bash
aws s3 rm s3://$BUCKET/index.html
aws s3 ls s3://$BUCKET/            # index.html appears gone…

aws s3api list-object-versions --bucket $BUCKET --prefix index.html \
  --query 'DeleteMarkers[].{VersionId:VersionId,IsLatest:IsLatest}' --output table
```

Undelete by removing the delete marker (paste the `VersionId` from above):

```bash
aws s3api delete-object --bucket $BUCKET --key index.html \
  --version-id PASTE_DELETE_MARKER_VERSION_ID

aws s3 ls s3://$BUCKET/            # it's back!
```

> 🖥️ **GUI checkpoint:** **S3 → your bucket → toggle "Show versions"** (top of the object list). Delete markers and old versions appear. Also open the **Properties** tab of the bucket:
> - **Default encryption** — every object is encrypted at rest (SSE-S3) automatically; you can upgrade to KMS keys here
> - **Bucket Versioning** — note it can be *suspended* but never fully turned off once enabled

### 4. Lifecycle rules — the cost saver

Old versions pile up and cost money. Lifecycle rules automate the janitorial work:

```bash
cat > lifecycle.json <<'EOF'
{
  "Rules": [
    {
      "ID": "expire-old-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 }
    },
    {
      "ID": "archive-logs",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" }
      ]
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket $BUCKET \
  --lifecycle-configuration file://lifecycle.json
```

> 🖥️ **GUI checkpoint:** **S3 → bucket → Management tab → Lifecycle rules**. The GUI wizard shows the full menu of **storage classes** (Standard → Standard-IA → Glacier Instant/Flexible/Deep Archive) with a nice diagram. Also worth showing: **Intelligent-Tiering**, which moves objects automatically based on access patterns so you don't have to guess the rules.

### 5. Presigned URLs — temporary access without accounts

Buckets are private by default (good!). To share one object with someone who has no AWS account, mint a time-limited signed URL:

```bash
aws s3 presign s3://$BUCKET/index.html --expires-in 300
```

Open the printed URL in your browser — it works. Wait 5 minutes — it dies. This is how apps let users download/upload files without ever proxying bytes through the backend.

### 6. Static website hosting

```bash
aws s3 website s3://$BUCKET/ \
  --index-document index.html \
  --error-document error.html
```

Websites need public reads. Two safety layers must agree. First, relax **Block Public Access** (on *this bucket only*):

```bash
aws s3api put-public-access-block \
  --bucket $BUCKET \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false
```

Second, a **bucket policy** that grants anonymous read:

```bash
cat > website-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicRead",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$BUCKET/*"
  }]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET --policy file://website-policy.json
```

Visit your site:

```bash
echo "http://$BUCKET.s3-website.$AWS_REGION.amazonaws.com"
```

Try a nonsense path too — your `error.html` should greet you.

> 🖥️ **GUI checkpoint:** **S3 → bucket → Permissions tab**. Three things to study:
> - **Block Public Access** — the master kill-switch. Its account-level version (S3 home page → left sidebar) overrides every bucket. This setting exists because leaked public buckets were the #1 cloud breach headline for a decade.
> - **Bucket policy** editor — with a built-in policy generator link
> - Note the difference from IAM: IAM policies say *this identity may do X anywhere it's allowed*; bucket policies say *this bucket accepts these actions from these principals*. Both are evaluated together.

### 7. Roles in action (connecting Part A to Part B)

Quick payoff for the role you built. Launch a minimal instance **with the instance profile**, then read the bucket *without any keys*:

```bash
export AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query 'Parameter.Value' --output text)

aws ec2 create-key-pair --key-name day2-key --key-type ed25519 \
  --query 'KeyMaterial' --output text > day2-key.pem && chmod 400 day2-key.pem

export SG_ID=$(aws ec2 create-security-group --group-name day2-sg \
  --description "ssh only" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID --instance-type t3.micro \
  --key-name day2-key --security-group-ids $SG_ID \
  --iam-instance-profile Name=bootcamp-ec2-profile-YOURNAME \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=day2-role-demo}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID
export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

ssh -i day2-key.pem ubuntu@$PUBLIC_IP
```

Inside the instance:

```bash
sudo snap install aws-cli --classic

# No aws configure. No keys. And yet:
aws sts get-caller-identity            # you ARE the role
aws s3 ls s3://bootcamp-YOURNAME-site  # allowed by your custom policy

# The policy only granted S3 read on ONE bucket, so:
aws s3 ls                              # AccessDenied — no ListAllMyBuckets
aws ec2 describe-instances             # AccessDenied — no EC2 at all
exit
```

Least privilege, demonstrated. 🔒

---

## 🧹 Cleanup

```bash
# EC2 demo instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name day2-key && rm -f day2-key.pem

# S3 — versioned buckets must be emptied of ALL versions before deletion
aws s3api delete-objects --bucket $BUCKET \
  --delete "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null

aws s3api delete-objects --bucket $BUCKET \
  --delete "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null

aws s3 rb s3://$BUCKET


rm -f s3-single-bucket-read.json ec2-trust.json lifecycle.json website-policy.json \
      index.html error.html && rm -rf assets
```

---