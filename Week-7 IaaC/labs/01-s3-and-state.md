# Lab 01 — S3 and Remote State

**Time: 25 minutes** · `code/01-s3-state/`

S3 is the simplest AWS service to Terraform, which makes it the perfect vehicle for the
single most important concept in the tool: **state**.

---

## Part A — Your first apply

```bash
cd code/01-s3-state
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and put your handle in. Then:

```bash
terraform init
```

Look at what appeared: a `.terraform/` directory (downloaded provider binaries — tens of
MB, never commit it) and `.terraform.lock.hcl`.

> **The lock file is the opposite of `.terraform/`: you MUST commit it.**
> It pins the exact provider versions *and their checksums*, so your laptop, your
> teammate's laptop and CI all get byte-identical providers. If you have ever heard
> "works on my machine" about infrastructure, this file is the cure.

Now:

```bash
terraform plan
```

Read the output properly. Every line begins with `+` (create), `-` (destroy),
`~` (update in place) or `-/+` (destroy and recreate). Note the summary at the bottom.

Some values show as `(known after apply)` — Terraform genuinely does not know the bucket
ARN until AWS assigns it. That is normal.

```bash
terraform apply
```

Type `yes`. Then check your outputs:

```bash
terraform output
```

**Copy the `data_bucket` value somewhere.** Lab 02 needs it.

---

## Part B — Look at the state file

```bash
terraform state list
```

That is the inventory of everything Terraform believes it owns. Inspect one:

```bash
terraform state show aws_s3_bucket.data
```

Now open `terraform.tfstate` in an editor. It is JSON. It contains every attribute of
every resource — **including secrets**, in plaintext, always.

> **Three rules of state, in order of how much they will hurt you:**
> 1. State is the source of truth for *what Terraform owns*, not what exists in AWS. Delete a bucket in the console and Terraform still thinks it exists — until the next refresh.
> 2. State contains secrets. `.gitignore` it. Encrypt it at rest.
> 3. Two people applying against the same state at the same time will corrupt it. Hence locking.

---

## Part C — Prove that state is the source of truth

Delete an object out from under Terraform:

```bash
aws s3 rm s3://<your-data-bucket>/hello.txt
```

Then:

```bash
terraform plan
```

Terraform notices the drift and plans to recreate it. This is **reconciliation**: your
`.tf` files describe desired state, AWS holds actual state, and `plan` is the diff.
Run `terraform apply` to heal it.

---

## Part D — Move state to S3

Local state is fine for one person on one laptop. It fails the moment there are two of you.

```bash
cp backend.tf.example backend.tf
```

Edit `backend.tf` and paste in your **state bucket** name (the `state_bucket` output).

> **Why can't you use `var.state_bucket` here?** Because the backend block is read
> *before* Terraform evaluates variables, locals or anything else — it has to know where
> state lives before it can load state. This trips up literally everyone once.
> The professional workaround is partial configuration:
> ```bash
> terraform init -backend-config="bucket=my-state-bucket"
> ```

Now migrate:

```bash
terraform init -migrate-state
```

Answer `yes`. Terraform copies your local state into S3. Verify:

```bash
aws s3 ls s3://<your-state-bucket>/lab01-s3/
terraform state list      # still works, now reading from S3
```

Note `use_lockfile = true` in the backend block. That is **native S3 locking**
(Terraform 1.11+) — it writes a `.tflock` object next to your state. The old approach
needed a whole DynamoDB table for this. If you are on Terraform 1.9 or 1.10, delete that
line; you are working solo today so locking is not critical.

---

## Checkpoint

- [ ] Two buckets exist, both with public access blocked
- [ ] `terraform output` gives you a `data_bucket` name (you wrote it down)
- [ ] State lives in S3 and `terraform state list` still works
- [ ] You can explain why the backend block cannot use a variable

## Stretch (if you finish early)

Add `s3:PutObject` denial for unencrypted uploads via `aws_s3_bucket_policy`, or turn on
`aws_s3_bucket_versioning` for the **data** bucket and watch what `terraform destroy` does
differently.
