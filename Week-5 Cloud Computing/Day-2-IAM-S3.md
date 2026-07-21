# Day 2 — IAM & S3: Who Can Do What, and Where Everything Lives

> **Today you will:** create users, groups, and policies; watch an `AccessDenied` turn into an `Allow`; give a *machine* permissions with a role (no passwords involved); then master S3 — buckets, versioning, lifecycle rules, presigned URLs, and a static website.

---

## 0. Setup

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-south-1
```

⚠️ IAM is **global** — users, groups, roles, and policies have no region. S3 bucket *names* are also global (unique across every AWS account on Earth), but each bucket's *data* lives in one region.

---

## Part A — IAM

### A1. Create a user and a group

The pattern in real teams: permissions go on **groups**, users go **in** groups. Never attach policies to individual users.

```bash
# A group for read-only auditors
aws iam create-group --group-name bootcamp-auditors

# Attach an AWS managed policy to the group
aws iam attach-group-policy \
  --group-name bootcamp-auditors \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# A user (use your own name to avoid collisions in the shared account)
aws iam create-user --user-name audit-YOURNAME

# Put the user in the group
aws iam add-user-to-group \
  --group-name bootcamp-auditors \
  --user-name audit-YOURNAME
```

Give the user CLI credentials:

```bash
aws iam create-access-key --user-name audit-YOURNAME
```

📋 Copy the `AccessKeyId` and `SecretAccessKey` from the output — the secret is shown **exactly once**.

### A2. Feel the AccessDenied

Configure a second CLI profile with the new user's keys:

```bash
aws configure --profile auditor
# paste the new keys, region ap-south-1, output table
```

Now test the boundary:

```bash
# Reading works — the group grants ReadOnlyAccess
aws ec2 describe-instances --profile auditor --output table

# Writing fails — enjoy your first deliberate AccessDenied
aws ec2 create-key-pair --key-name should-fail --profile auditor
```

🎉 That `UnauthorizedOperation` error is IAM doing its job. Read it carefully — AWS error messages tell you *which action* on *which resource* was denied, and (in newer messages) even *why*.

> 🖥️ **GUI checkpoint:** **IAM → Users → audit-YOURNAME**:
> - **Permissions** tab — see the policy inherited *via the group*
> - **Security credentials** tab — this is where **MFA** is enabled. In any real account, no MFA = no console access. Also note **console password** vs **access keys** are separate credentials: one for humans in a browser, one for CLI/scripts.
> - **IAM → Policy simulator** (left sidebar, bottom) — pick your user, pick an action like `ec2:TerminateInstances`, hit Run. This is the #1 tool for debugging "why can't I…?" without trial-and-error in production.

### A3. Write a custom policy

Managed policies are coarse. Real security means writing your own. This one allows S3 read on a single bucket only:

```bash
cat > s3-single-bucket-read.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListTheBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::bootcamp-YOURNAME-site"
    },
    {
      "Sid": "ReadObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::bootcamp-YOURNAME-site/*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name bootcamp-s3-read-YOURNAME \
  --policy-document file://s3-single-bucket-read.json
```

📝 **Anatomy to remember:** `Effect` (Allow/Deny) + `Action` (the API call) + `Resource` (the ARN it applies to). An explicit `Deny` always beats any `Allow`. Note the two resources: the bucket itself for `ListBucket`, and `/*` (the objects inside) for `GetObject` — mixing these up is the most common IAM policy bug in existence.

### A4. Roles — permissions for machines

Yesterday your EC2 instance had **no** AWS permissions. The wrong fix: paste access keys into the box (they leak, they never rotate, they end up on GitHub). The right fix: an **IAM role** the instance *assumes* — temporary credentials, auto-rotated, nothing stored on disk.

A role needs a **trust policy** (who may assume it) and **permission policies** (what it may do):

```bash
cat > ec2-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name bootcamp-ec2-s3-role-YOURNAME \
  --assume-role-policy-document file://ec2-trust.json

aws iam attach-role-policy \
  --role-name bootcamp-ec2-s3-role-YOURNAME \
  --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/bootcamp-s3-read-YOURNAME

# EC2 attaches roles via an "instance profile" wrapper
aws iam create-instance-profile \
  --instance-profile-name bootcamp-ec2-profile-YOURNAME

aws iam add-role-to-instance-profile \
  --instance-profile-name bootcamp-ec2-profile-YOURNAME \
  --role-name bootcamp-ec2-s3-role-YOURNAME
```

We'll attach this to an instance in Part B and watch it work.

> 🖥️ **GUI checkpoint:** **IAM → Roles → your role → Trust relationships** tab. The trust policy is what makes roles magical: change the Principal and the same mechanism gives permissions to Lambda functions, EKS pods, other AWS accounts, or your GitHub Actions pipeline (that's the OIDC keyless auth you used in the CI/CD module — same idea!).

**The mantra: humans get users+MFA, machines get roles, nobody gets `*`.**

---

## Part B — S3

### B1. Create a bucket

Bucket names are globally unique — use your name:

```bash
export BUCKET=bootcamp-YOURNAME-site

aws s3 mb s3://$BUCKET --region $AWS_REGION
```

### B2. Upload things

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

### B3. Versioning — the undo button

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

### B4. Lifecycle rules — the cost saver

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

### B5. Presigned URLs — temporary access without accounts

Buckets are private by default (good!). To share one object with someone who has no AWS account, mint a time-limited signed URL:

```bash
aws s3 presign s3://$BUCKET/index.html --expires-in 300
```

Open the printed URL in your browser — it works. Wait 5 minutes — it dies. This is how apps let users download/upload files without ever proxying bytes through the backend.

### B6. Static website hosting

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

### B7. Roles in action (connecting Part A to Part B)

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

# IAM — dependencies must go first (keys → group membership → user, etc.)
aws iam list-access-keys --user-name audit-YOURNAME \
  --query 'AccessKeyMetadata[].AccessKeyId' --output text | \
  xargs -n1 -I{} aws iam delete-access-key --user-name audit-YOURNAME --access-key-id {}
aws iam remove-user-from-group --group-name bootcamp-auditors --user-name audit-YOURNAME
aws iam delete-user --user-name audit-YOURNAME
aws iam detach-group-policy --group-name bootcamp-auditors \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam delete-group --group-name bootcamp-auditors

aws iam remove-role-from-instance-profile \
  --instance-profile-name bootcamp-ec2-profile-YOURNAME \
  --role-name bootcamp-ec2-s3-role-YOURNAME
aws iam delete-instance-profile --instance-profile-name bootcamp-ec2-profile-YOURNAME
aws iam detach-role-policy --role-name bootcamp-ec2-s3-role-YOURNAME \
  --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/bootcamp-s3-read-YOURNAME
aws iam delete-role --role-name bootcamp-ec2-s3-role-YOURNAME
aws iam delete-policy \
  --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/bootcamp-s3-read-YOURNAME

rm -f s3-single-bucket-read.json ec2-trust.json lifecycle.json website-policy.json \
      index.html error.html && rm -rf assets
```

---

## ✅ Day 2 Checklist

- [ ] Created a user + group, attached a managed policy, felt an AccessDenied
- [ ] Wrote a custom least-privilege policy from scratch
- [ ] Built a role with a trust policy and attached it to EC2 via instance profile
- [ ] Watched an instance call AWS APIs with zero stored credentials
- [ ] Created a bucket; used both `aws s3` and `aws s3api`
- [ ] Enabled versioning; deleted and *undeleted* an object
- [ ] Set lifecycle rules; understood storage classes
- [ ] Generated a presigned URL and hosted a static website
- [ ] Cleaned up in the correct dependency order

## 🏠 Homework

1. Use the **Policy Simulator** to find three actions your `audit-YOURNAME` user *can* do and three it *cannot*. Screenshot the results.
2. Write a policy that allows `s3:PutObject` into `logs/` prefix only, on your bucket. What happens if you also add an explicit Deny for `s3:DeleteObject` on the same prefix — who wins, and why?
