# Lab 01 — Terraform Manages... Files?

Yes, files. No cloud, no credentials, no bill. Everything that makes Terraform *Terraform*
— the workflow, the state file, the plan diff, drift detection — works on your laptop's
filesystem. Learn the engine here; swap the backend later.

## What you'll learn

- The core loop: `init → plan → apply → destroy`
- What the **state file** is and why Terraform is useless without it
- **Drift**: what happens when reality disagrees with state
- Variables, outputs, `templatefile()`, and `for_each`

---

## Step 1 — Init

```bash
terraform init
```

Look at what appeared: a `.terraform/` directory (downloaded provider plugins) and
`.terraform.lock.hcl` (pinned provider versions — commit this file). Terraform just
downloaded the `local` and `random` providers. **Terraform core cannot create a file.**
Only providers can do things.

## Step 2 — Plan

```bash
terraform plan
```

Read the diff carefully. `+` means create. Note it plans **5 resources**: 1 hello file,
1 random name, 1 config file, 3 student files. Nothing has happened yet — plan is a dry run.

## Step 3 — Apply

```bash
terraform apply     # type: yes
ls -R output/
cat output/server-config.ini
```

Also look at the new `terraform.tfstate` file:

```bash
cat terraform.tfstate | head -40
```

This JSON is Terraform's memory — its record of what it created. It's how Terraform knows,
next time you run `plan`, that these files are *its* files.

## Step 4 — Idempotency

```bash
terraform apply
```

"No changes." Desired state == real state == recorded state. This is the whole game.

## Step 5 — Drift (the important one)

Sabotage your own infrastructure:

```bash
echo "I edited this by hand, what are you gonna do about it" > output/hello.txt
rm output/students/asha.txt
terraform plan
```

Terraform **refreshes** (re-reads reality), compares against desired state, and plans to
fix both: overwrite the edited file, recreate the deleted one. Run `terraform apply` and
watch it heal. Cloud version of this story: someone clicks around in the AWS console,
next `plan` reveals everything they touched.

## Step 6 — Change a variable

```bash
terraform apply -var='students=["asha","bibek","chandra","divya"]'
```

Only **one** resource is added — Terraform diffs, it doesn't rebuild. Now remove
`bibek` from the list and apply again: one targeted destroy.

## Step 7 — Destroy

```bash
terraform destroy
ls output/ 2>/dev/null   # gone
```

## Checkpoint questions

1. What breaks if you delete `terraform.tfstate` and run `plan`? (Try it — then
   `terraform destroy` will orphan nothing because Terraform forgot everything. Manually
   delete `output/` and re-apply to recover.)
2. Why is `random_pet` always created before `server_config`? Run `terraform graph` to see.
3. Why does `for_each` use `each.key` in the filename?

## Stretch

- Add a `local_sensitive_file` containing a fake password and see how outputs redact it.
- Change `random_pet.length` to 3 — why does the config file get replaced too?
