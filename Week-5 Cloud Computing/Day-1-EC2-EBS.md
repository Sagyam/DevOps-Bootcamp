# Day 1 — EC2 & EBS: Your First Server in the Cloud

> **Today you will:** launch a real Linux server on AWS, SSH into it, serve a web page from it, then attach, grow, snapshot, and restore a disk — all from the command line.

---

## 0. Before You Start

### Prerequisites

- An AWS account (you should have received credentials from your instructor)
- AWS CLI v2 installed (`aws --version` should print `aws-cli/2.x`)
- A terminal (Linux/macOS/WSL/Git Bash)

### Configure the CLI

```bash
aws configure
```

Enter when prompted:

| Prompt | Value |
|---|---|
| AWS Access Key ID | *(your key)* |
| AWS Secret Access Key | *(your secret)* |
| Default region name | `ap-south-1` |
| Default output format | `table` |

> **Why `ap-south-1`?** That's Mumbai — the closest AWS region to Nepal, which means the lowest latency for us. Every resource you create today lives in this region. If you can't find your stuff in the console later, check the region selector in the top-right corner first.

Verify you are who you think you are:

```bash
aws sts get-caller-identity
```

Save your account ID for later — we'll need it all week:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo $AWS_ACCOUNT_ID
```

> 🖥️ **GUI checkpoint:** Log into the AWS Console. Note the **region selector** (top-right) and the **search bar** (top-left). Open **EC2** now and keep the tab open — we'll compare console and CLI views all day.

---

## Part A — EC2

### A1. Find an AMI (the OS image)

Every EC2 instance boots from an **AMI** — a snapshot of an operating system. Let's find the latest Ubuntu 24.04 image via AWS's public parameter store (this always resolves to the current image, so you never hardcode a stale AMI ID):

```bash
export AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query 'Parameter.Value' --output text)

echo $AMI_ID
```

> 🖥️ **GUI checkpoint:** In the console: **EC2 → Launch instance**. Look at the **AMI catalog** — Quick Start vs Marketplace vs Community AMIs. Notice each AMI ID is region-specific: the Ubuntu 24.04 AMI in Mumbai has a *different ID* than the same image in Virginia.

### A2. Create an SSH key pair

```bash
aws ec2 create-key-pair \
  --key-name bootcamp-key \
  --key-type ed25519 \
  --query 'KeyMaterial' \
  --output text > bootcamp-key.pem

chmod 400 bootcamp-key.pem
```

⚠️ AWS stores only the **public** half. The `.pem` file you just saved is the private key — lose it and you can never SSH into instances created with it. There is no "download again" button.

### A3. Create a security group (the firewall)

A **security group** is a stateful firewall attached to your instance. Default: all inbound blocked, all outbound allowed.

```bash
export SG_ID=$(aws ec2 create-security-group \
  --group-name bootcamp-web-sg \
  --description "SSH and HTTP for bootcamp day 1" \
  --query 'GroupId' --output text)

echo $SG_ID
```

Open port 22 (SSH) and port 80 (HTTP):

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
```

> 🖥️ **GUI checkpoint:** **EC2 → Security Groups → bootcamp-web-sg → Inbound rules**. Two things worth exploring in the GUI:
> 1. The **Source** dropdown lets you pick "My IP" — in real life you'd lock SSH to your own IP instead of `0.0.0.0/0` (the whole internet).
> 2. Rules can reference *other security groups* as a source — that's how you say "only my web servers may talk to my database."

### A4. Find a subnet to launch into

`run-instances` needs a **subnet** to place the instance's network interface in. Normally it'll pick a default subnet for you automatically — but in a shared bootcamp account, the default VPC's subnets are sometimes missing (deleted by a previous exercise, or never created), which gives you `MissingInput: No subnets found for the default VPC`. Look one up explicitly so it works either way:

```bash
export SUBNET_ID=$(aws ec2 describe-subnets \
  --filters Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)

echo $SUBNET_ID
```

> ⚠️ If this prints `None`, your account's default VPC has no subnets at all and needs an admin to recreate them (`aws ec2 create-default-subnet --availability-zone us-east-1a`, once per AZ) — flag it to your instructor.

Also grab your identity to tag resources with, instead of hardcoding a name:

```bash
export OWNER=$(aws sts get-caller-identity --query Arn --output text | awk -F/ '{print $NF}')
echo $OWNER
```

### A5. Launch the instance

We'll pass a **user data** script — a shell script that runs once at first boot. Ours installs nginx:

```bash
cat > user-data.sh <<'EOF'
#!/bin/bash
apt-get update -y
apt-get install -y nginx
echo "<h1>Hello from $(hostname) — launched by $(whoami) via user-data</h1>" > /var/www/html/index.html
EOF
```

Launch:

```bash
export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name bootcamp-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --user-data file://user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=day1-web},{Key=owner,Value=$OWNER}]" \
  --query 'Instances[0].InstanceId' --output text)

echo $INSTANCE_ID
```

Tags are how humans (and billing reports) find things in a shared account — the `owner` tag is now filled in automatically from `$OWNER`, no manual editing needed.

Wait until it's running and grab the public IP:

```bash
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

export PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo $PUBLIC_IP
```

### A6. Verify

Open `http://<PUBLIC_IP>` in your browser (give it ~1 minute — user-data runs *after* boot). You should see the nginx hello page.

SSH in:

```bash
ssh -i bootcamp-key.pem ubuntu@$PUBLIC_IP
```

Once inside, poke around:

```bash
# Instance metadata service (IMDSv2) — the instance asking AWS about itself
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type
curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4

# Check the user-data log
sudo tail -20 /var/log/cloud-init-output.log

exit
```

> 🖥️ **GUI checkpoint:** **EC2 → Instances → day1-web**. Explore the tabs:
> - **Details** — public/private IPs, AMI, subnet, IAM role (empty for now — Day 2 fixes that)
> - **Monitoring** — free CPU/network graphs (foreshadowing Day 4)
> - **Actions → Instance settings → Edit user data** — user-data can be edited, but only while stopped
> - **Connect → EC2 Instance Connect** — browser-based SSH without a `.pem` file. Handy when your key is on another machine.

### A7. Instance lifecycle

```bash
# Stop (billing for compute stops; the disk persists; PUBLIC IP CHANGES on restart!)
aws ec2 stop-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID

# Start again
aws ec2 start-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# New public IP — check it:
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

📝 **Note this down:** stop/start ≠ reboot. A stopped instance costs nothing for compute (you still pay for its EBS disk), and gets a **new public IP** when it comes back. If you need a permanent IP, that's an **Elastic IP** — check **EC2 → Elastic IPs** in the console (we won't allocate one today; an *unattached* Elastic IP costs money).

Update your variable with the new IP:

```bash
export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
```

---

## Part B — EBS

Your instance's root disk *is already* an EBS volume. Now we'll add a second one — the workflow you'd use to give a database its own data disk.

### B1. See what you already have

```bash
aws ec2 describe-volumes \
  --filters Name=attachment.instance-id,Values=$INSTANCE_ID \
  --query 'Volumes[].{ID:VolumeId,Size:Size,Type:VolumeType,Device:Attachments[0].Device}' \
  --output table
```

### B2. Create a new volume

EBS volumes live in a single **Availability Zone** and can only attach to instances in that same AZ. Find your instance's AZ first:

```bash
export AZ=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)
echo $AZ
```

Create a 10 GB gp3 volume there:

```bash
export VOL_ID=$(aws ec2 create-volume \
  --availability-zone $AZ \
  --size 10 \
  --volume-type gp3 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=day1-data}]' \
  --query 'VolumeId' --output text)

aws ec2 wait volume-available --volume-ids $VOL_ID
echo $VOL_ID
```

> 🖥️ **GUI checkpoint:** **EC2 → Volumes → Create volume**. Look at the **Volume type** dropdown: `gp3` (general purpose, what you almost always want), `io2` (provisioned IOPS for serious databases), `st1`/`sc1` (cheap spinning disks for logs/archives). With gp3 selected, notice you can dial **IOPS** and **throughput** *independently of size* — that's the gp3 superpower over the older gp2.

### B3. Attach it

```bash
aws ec2 attach-volume \
  --volume-id $VOL_ID \
  --instance-id $INSTANCE_ID \
  --device /dev/sdf
```

### B4. Format and mount (inside the instance)

```bash
ssh -i bootcamp-key.pem ubuntu@$PUBLIC_IP
```

```bash
# Find the new disk — on modern instances /dev/sdf shows up as an NVMe device
lsblk

# It's the ~10G disk with no partitions, usually /dev/nvme1n1
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir /data
sudo mount /dev/nvme1n1 /data

# Prove it works
echo "important production data $(date)" | sudo tee /data/precious.txt
df -h /data
exit
```

### B5. Snapshot it

A **snapshot** is a point-in-time backup of a volume, stored (incrementally) in S3 behind the scenes:

```bash
export SNAP_ID=$(aws ec2 create-snapshot \
  --volume-id $VOL_ID \
  --description "day1 data disk backup" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=day1-backup}]' \
  --query 'SnapshotId' --output text)

aws ec2 wait snapshot-completed --snapshot-ids $SNAP_ID
echo $SNAP_ID
```

### B6. Grow the volume — live, no downtime

```bash
aws ec2 modify-volume --volume-id $VOL_ID --size 20
```

The *AWS side* is now 20 GB, but the *filesystem* still thinks it's 10 GB. SSH back in and grow the filesystem:

```bash
ssh -i bootcamp-key.pem ubuntu@$PUBLIC_IP
sudo resize2fs /dev/nvme1n1
df -h /data          # now ~20G
exit
```

📝 **Note this down:** volumes can be grown but **never shrunk**. To go smaller you snapshot, create a smaller volume, and copy data over.

### B7. Disaster strikes — restore from snapshot

Simulate losing the disk, then bring the data back:

```bash
# "Accidentally" destroy the volume
ssh -i bootcamp-key.pem ubuntu@$PUBLIC_IP "sudo umount /data"
aws ec2 detach-volume --volume-id $VOL_ID
aws ec2 wait volume-available --volume-ids $VOL_ID
aws ec2 delete-volume --volume-id $VOL_ID

# Resurrect from snapshot
export VOL2_ID=$(aws ec2 create-volume \
  --availability-zone $AZ \
  --snapshot-id $SNAP_ID \
  --volume-type gp3 \
  --query 'VolumeId' --output text)

aws ec2 wait volume-available --volume-ids $VOL2_ID
aws ec2 attach-volume --volume-id $VOL2_ID --instance-id $INSTANCE_ID --device /dev/sdf
```

Mount and check that `precious.txt` survived:

```bash
ssh -i bootcamp-key.pem ubuntu@$PUBLIC_IP
sudo mount /dev/nvme1n1 /data     # no mkfs this time — the filesystem came with the snapshot!
cat /data/precious.txt
exit
```

> 🖥️ **GUI checkpoint:** **EC2 → Snapshots**. Right-click your snapshot: from here you can **create a volume in a different AZ**, **copy to another region** (disaster recovery), or even **create an AMI** from a root-volume snapshot. Snapshots are the currency of EC2 backup and migration.

---

## 🧹 Cleanup (do not skip!)

You're in a shared account. Untidy resources cost real money.

```bash
# Terminate the instance (this also deletes its ROOT volume by default)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID

# The extra data volume does NOT auto-delete — remove it
aws ec2 delete-volume --volume-id $VOL2_ID

# Delete the snapshot
aws ec2 delete-snapshot --snapshot-id $SNAP_ID

# Delete the security group and key pair
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name bootcamp-key
rm -f bootcamp-key.pem user-data.sh
```

Verify nothing is left:

```bash
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output table

aws ec2 describe-volumes --query 'Volumes[].VolumeId' --output table
```

---

## ✅ Day 1 Checklist

- [ ] Configured AWS CLI and verified identity with `sts get-caller-identity`
- [ ] Launched an EC2 instance with a user-data script
- [ ] SSH'd in and queried instance metadata (IMDSv2)
- [ ] Understood stop vs terminate, and why public IPs change
- [ ] Created, attached, formatted, and mounted an EBS volume
- [ ] Grew a volume live and resized the filesystem
- [ ] Restored data from a snapshot after "losing" a disk
- [ ] Cleaned everything up

## 🏠 Homework

1. Launch an instance whose user-data installs Docker and runs `stefanprodan/podinfo:6.14.0` on port 80. (You already know podinfo from the Kubernetes module — it returns to AWS on Day 3.)
2. In one paragraph: your team runs a MySQL server on EC2. Describe your backup strategy using what you learned today, including how you'd test that backups actually work.
