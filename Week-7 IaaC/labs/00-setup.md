# Lab 00 — Setup & Sanity Check

**Time: 15 minutes**

You already have an AWS account and Terraform installed. This lab makes sure your
laptop can actually *talk* to AWS, and gets everyone onto the same page regardless
of operating system.

---

## 1. Pick your handle

Every resource you create gets prefixed with a name you choose. This is how 20 people
share one AWS account without colliding.

Rules: **3–20 characters, lowercase letters, digits and hyphens only.** S3 bucket names
are DNS names — `Sagyam_Thapa` is illegal, `sagyam` is fine.

Write it down. You will type it into every lab.

---

## 2. Verify your tools

Run these four commands. All four must succeed before you continue.

```bash
terraform version     # need >= 1.9
aws --version         # need >= 2.x
kubectl version --client
docker version        # optional — only needed for the ECR bonus
```

### If a command is missing

| Tool | Windows (PowerShell, as admin) | macOS | Linux |
|---|---|---|---|
| AWS CLI | `winget install Amazon.AWSCLI` | `brew install awscli` | `sudo snap install aws-cli --classic` |
| kubectl | `winget install Kubernetes.kubectl` | `brew install kubectl` | `sudo snap install kubectl --classic` |
| Terraform | `winget install HashiCorp.Terraform` | `brew install terraform` | see terraform.io/downloads |

> **Windows students:** you can use **PowerShell 7** or **Git Bash**. Both work.
> Pick one and stay in it for the whole session — mixing them mid-lab is how you end up
> with `$env:VAR` set in one window and `export VAR` in the other, wondering why nothing
> matches. Every command in this course is written to work in both.

---

## 3. Configure credentials

```bash
aws configure
```

Enter your access key, secret key, region `ap-south-1`, and output format `json`.

Where your credentials land:

| OS | Path |
|---|---|
| Windows | `%USERPROFILE%\.aws\credentials` |
| macOS / Linux | `~/.aws/credentials` |

Now prove it works:

```bash
aws sts get-caller-identity
```

You should see your account ID and your ARN. **If this command fails, nothing in the
next three hours will work.** Fix it now.

---

## 4. Get the lab code

```bash
cd terraform-lab
```

You will see:

```
code/
  01-s3-state/     02-iam/     03-ec2-ebs/
  04-ecr/          05-eks/     06-kubernetes/
labs/              <- you are here
```

Each `code/` folder is a **root module** — its own directory, its own `terraform init`,
its own state file. That is deliberate. One giant Terraform directory that manages your
network, your database and your app is the most common architectural mistake in this
ecosystem: every `apply` refreshes everything and every mistake has a blast radius of
"the whole company".

---

## 5. How to work through these labs

The `code/` folders contain the **finished** configuration. You will get roughly 3× more
out of today if you open a blank `main.tf` and type it yourself, using the provided file
only when you are stuck. Reading Terraform is easy. Writing it is where the learning is.

Every lab follows the same rhythm:

```bash
terraform init      # download providers, set up the backend
terraform fmt       # canonical formatting — run it before every commit
terraform validate  # syntax + type checking, no AWS calls
terraform plan      # what WOULD change
terraform apply      # do it
```

**Never skip `plan`.** In this room it costs you eight seconds. In production it is the
difference between a deploy and an incident.

---

## Cost warning — read this

Today's resources cost roughly **$0.30–$0.80 total** if you destroy them at the end.
The expensive one is EKS: the control plane is billed at ~$0.10/hour **whether or not
you use it**, and it keeps billing while you sleep.

Lab 07 is the teardown lab. **Do not leave early without doing it.**
