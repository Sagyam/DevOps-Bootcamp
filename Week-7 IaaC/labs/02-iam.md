# Lab 02 — IAM

**Time: 25 minutes** · `code/02-iam/`

IAM is the service that most often stands between you and a working deployment. Learn to
read its two policy types and half of your AWS debugging is done.

---

## The one distinction that matters

Every IAM role has **two** policies attached, and they answer different questions:

| | Question it answers | Where it lives |
|---|---|---|
| **Trust policy** | *Who is allowed to become this role?* | `assume_role_policy` on the role |
| **Permission policy** | *What can this role do, once assumed?* | attached separately |

`AccessDenied` almost always means the permission policy is wrong.
`is not authorized to perform: sts:AssumeRole` means the **trust** policy is wrong.
They are completely different failures with confusingly similar names.

---

## Steps

```bash
cd ../02-iam
cp terraform.tfvars.example terraform.tfvars
```

Edit it: your handle, plus the `data_bucket` name from Lab 01.

```bash
terraform init
terraform plan
terraform apply
```

---

## Part A — Read the policy document

Open `main.tf` and find `data "aws_iam_policy_document" "s3_read"`. It has **two**
statements, and the difference between them is the classic IAM trap:

```
arn:aws:s3:::my-bucket        <- the bucket. For s3:ListBucket.
arn:aws:s3:::my-bucket/*      <- the objects. For s3:GetObject.
```

They are different resources. `s3:ListBucket` on `my-bucket/*` silently does nothing.
`s3:GetObject` on `my-bucket` silently does nothing. Every AWS engineer loses an hour to
this exactly once.

See the rendered JSON:

```bash
terraform console
```
```
> data.aws_iam_policy_document.s3_read.json
```
Type `exit` to leave. `terraform console` is an underused debugging tool — you can
evaluate any expression, function or resource attribute against real state.

---

## Part B — Instance profiles

EC2 cannot wear an IAM role directly. It wears an **instance profile**, which is a thin
container holding exactly one role. In the console AWS hides this and shows you "IAM role",
which is why the resource surprises people in Terraform.

```bash
terraform output instance_profile_name
```

Lab 03 looks this profile up **by name**, so do not rename it.

---

## Part C — Understand what you did NOT create

We created a role, not a user. That is deliberate.

- **IAM users** = long-lived access keys that leak into git history, laptops and Slack.
- **IAM roles** = short-lived credentials, auto-rotated, scoped to a workload.

For humans, the modern answer is **IAM Identity Center** (SSO), not IAM users.
For workloads on EC2/EKS/Lambda, it is always roles. If you find yourself creating an
IAM user in 2026, stop and ask why.

---

## Checkpoint

- [ ] Role, policy and instance profile exist
- [ ] You can state the difference between a trust policy and a permission policy
- [ ] You can explain why `arn:...:bucket` and `arn:...:bucket/*` are both needed
- [ ] `terraform output instance_profile_name` returns `<handle>-tflab-ec2-profile`

## Stretch

Change `s3:GetObject` to `s3:*` and run `terraform plan`. Notice Terraform reports it as an
in-place update, not a replacement — IAM policies are versioned by AWS, and Terraform
creates a new version rather than destroying the policy. Revert it afterwards.
