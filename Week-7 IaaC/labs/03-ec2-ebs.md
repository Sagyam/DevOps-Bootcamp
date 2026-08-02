# Lab 03 — EC2 and EBS

**Time: 30 minutes** · `code/03-ec2-ebs/`

A server and a disk. Along the way: data sources, `user_data`, and why compute and storage
have separate lifecycles.

**Prerequisite:** Lab 02 must be applied — this lab looks up the instance profile by name.

---

## Steps

```bash
cd ../03-ec2-ebs
cp terraform.tfvars.example terraform.tfvars   # edit your handle
terraform init
terraform plan
terraform apply
```

Apply takes ~40 seconds. The instance then needs another ~90 seconds to finish its
`user_data` script.

```bash
terraform output url
```

Open that URL in a browser. You should see a dark page showing `lsblk` and `df -h` from
inside your instance, with your extra volume mounted at `/data`.

> **If the page does not load:** wait another minute (user_data is still running), then
> check that `terraform output allowed_from` matches your actual public IP. If you are on
> a VPN or your ISP rotated your address, re-run `terraform apply` — the security group
> rule is derived from a live lookup of your IP and will update itself.

---

## Part A — Data sources: read, don't hardcode

Open `data.tf`. Four things are looked up rather than typed:

```hcl
data "aws_vpc" "default"           # the VPC that already exists
data "aws_ssm_parameter" "al2023"  # the current Amazon Linux AMI ID
data "aws_iam_instance_profile"    # Lab 02's output, by name
data "http" "my_ip"                # your own public IP
```

The AMI one matters most. **Never hardcode an AMI ID.** They are region-specific and change
every time Amazon patches the image. Reading the SSM public parameter means your config
works in Mumbai and Singapore, today and in six months.

`data "http" "my_ip"` runs on every plan. If your IP changes, the next plan shows a diff on
the security group. That is a feature: your config genuinely no longer matches reality.

---

## Part B — Two kinds of disk

This is the lab's real lesson. Look at `main.tf`:

```hcl
resource "aws_instance" "web" {
  root_block_device { ... }        # <- inline. Dies with the instance.
}

resource "aws_ebs_volume" "data" { ... }        # <- separate resource
resource "aws_volume_attachment" "data" { ... } # <- the link
```

The root volume is a **block inside** the instance. It is created and destroyed with the
instance, full stop.

The data volume is its **own resource**. Terminate the instance and this volume survives,
with your data on it, ready to attach elsewhere. That is why databases live on separate
EBS volumes and root volumes stay disposable.

Prove it — force a replacement:

```bash
terraform apply -replace=aws_instance.web
```

Read the plan carefully before confirming. The instance is destroyed and recreated. The
`aws_ebs_volume` is **not** — only the attachment is recreated. Your `/data/proof.txt`
is still there when the new instance boots.

---

## Part C — The Nitro device-name gotcha

Open `user_data.sh` and find the polling loop.

Terraform attaches the volume as `/dev/sdf`. On a Nitro instance (t3, m5, c5, and
everything modern) the kernel actually names it `/dev/nvme1n1`. Amazon Linux ships udev
rules that create a `/dev/sdf` symlink, but there is a second problem: the attachment can
complete *after* the instance has booted and run your script.

Hence: poll for the device, then mount **by UUID** in `/etc/fstab`, never by device name.
Device names are not stable across reboots. `nofail` is there so that a missing volume
does not leave the box unbootable.

You can shell in and check — no SSH key, no port 22, works identically on all three OSes:

```bash
aws ssm start-session --target <instance-id> --region ap-south-1
```
(Needs the Session Manager plugin installed; the browser page shows the same information
if you'd rather skip it.)

---

## Part D — `user_data_replace_on_change`

Edit the heading text inside `user_data.sh`, then:

```bash
terraform plan
```

Terraform plans to **replace** the instance. Without
`user_data_replace_on_change = true`, Terraform would update the attribute and the running
server would never re-run the script — your config and reality would silently diverge.

This is a general principle worth taking away: **cattle, not pets.** Changing the
definition of a server means replacing the server.

---

## Checkpoint

- [ ] Browser page loads and shows the extra volume mounted at `/data`
- [ ] You can explain why the root volume and the data volume have different lifecycles
- [ ] You know why AMI IDs must never be hardcoded
- [ ] `-replace` destroyed the instance but kept the EBS volume

## Stretch

Add `resource "aws_ebs_snapshot"` for the data volume. Or change `volume_size` from 5 to 8
and note that EBS grows in place (no replacement) — but the filesystem inside does not,
until you run `growpart` and `resize2fs`.
