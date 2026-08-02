# Lab 04 — ECR

**Time: 15 minutes** · `code/04-ecr/`

A private container registry. Short lab, but it sets up the EKS story: your nodes will
pull from here.

---

## Steps

```bash
cd ../04-ecr
cp terraform.tfvars.example terraform.tfvars   # edit your handle
terraform init
terraform apply
terraform output
```

---

## Part A — Immutable tags

Look at this line:

```hcl
image_tag_mutability = "IMMUTABLE"
```

With `MUTABLE`, someone can push a different image over `:v1.2.3`. Your cluster then runs
code that does not match the git tag it claims to be — and the only symptom is
"it worked yesterday". With `IMMUTABLE`, a tag is permanent.

The related habit: **never deploy `:latest`.** `:latest` means "whatever was pushed most
recently", which means a pod restarting at 3am can pick up a different image than its
sibling. Deploy digests or immutable semver tags.

---

## Part B — Lifecycle policy

ECR storage is billed per GB-month. A CI pipeline pushing on every commit will fill a repo
with hundreds of images nobody will ever pull again.

```hcl
countType   = "imageCountMoreThan"
countNumber = 10
```

Ten images kept, the rest expire. Set this on day one; retrofitting it onto a 400 GB repo
is a much less pleasant afternoon.

---

## Part C — Push an image (optional — needs Docker)

```bash
terraform output -raw login_command
```

Copy and run it. That command works unchanged in **bash, zsh and PowerShell** — the pipe
into `--password-stdin` is portable.

Then:

```bash
terraform output -raw push_commands
```

Run those three lines. You are pulling a public podinfo image, retagging it for your
registry and pushing.

Verify:

```bash
aws ecr describe-images --repository-name <handle>/podinfo --region ap-south-1
```

> **No Docker installed?** Skip this part. Lab 06 deploys from a public registry by
> default; using your ECR image is the bonus step there.

---

## Part D — Note `force_delete = true`

```hcl
force_delete = true
```

Without it, `terraform destroy` fails with `RepositoryNotEmptyException` because AWS
refuses to delete a repo containing images. This is **lab-only**. In production that
guardrail is exactly what you want.

You will meet the same pattern again with S3 (`force_destroy`) and RDS
(`skip_final_snapshot`). Terraform cannot delete a stateful resource that AWS is
protecting, and the answer is always an explicit "yes, I mean it" flag.

---

## Checkpoint

- [ ] Repository exists with scan-on-push enabled
- [ ] You can explain what `IMMUTABLE` prevents
- [ ] You know why `force_delete` is a lab-only setting
