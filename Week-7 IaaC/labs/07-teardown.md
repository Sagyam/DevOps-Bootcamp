# Lab 07 — Teardown

**Time: 15 minutes** · **Nobody leaves without doing this.**

The EKS control plane bills ~$0.10/hour forever, whether you use it or not. A forgotten lab
cluster is a $72/month invoice.

---

## Destroy in reverse order

Dependencies run downhill; destruction runs uphill. Go backwards through the labs:

```bash
cd code/06-kubernetes && terraform destroy -auto-approve
cd ../05-eks         && terraform destroy -auto-approve   # ~10 minutes
cd ../04-ecr         && terraform destroy -auto-approve
cd ../03-ec2-ebs     && terraform destroy -auto-approve
cd ../02-iam         && terraform destroy -auto-approve
cd ../01-s3-state    && terraform destroy -auto-approve   # LAST — holds your state
```

> **Windows PowerShell:** `&&` works in PowerShell 7 but **not** in Windows PowerShell 5.1.
> If you get a parse error, run the two halves as separate lines, or use `;` instead.

**Lab 06 must go first.** If you skip it and destroy the cluster underneath it, the
`kubernetes` provider can no longer reach an endpoint that no longer exists, and you are
left with orphaned entries in state that you have to `terraform state rm` by hand.

**Lab 01 must go last** — its bucket holds your state file. Destroying it first strands
everything else.

Or just run the script:

```bash
bash scripts/destroy-all.sh          # macOS / Linux / Git Bash
pwsh scripts/destroy-all.ps1         # Windows PowerShell
```

---

## Verify with your eyes, not with Terraform

`terraform destroy` succeeding is necessary but not sufficient. Anything created *by*
Kubernetes rather than by Terraform — load balancers, EBS volumes from PVCs — is invisible
to your state file and keeps billing happily.

```bash
aws eks list-clusters --region ap-south-1
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId"
aws elbv2 describe-load-balancers --region ap-south-1 --query "LoadBalancers[].LoadBalancerName"
aws elb describe-load-balancers --region ap-south-1 --query "LoadBalancerDescriptions[].LoadBalancerName"
aws ec2 describe-volumes --region ap-south-1 \
  --filters "Name=status,Values=available" --query "Volumes[].VolumeId"
aws ecr describe-repositories --region ap-south-1 --query "repositories[].repositoryName"
```

All should come back empty. **Three classic leftovers:**

1. **Load balancers** from a `type: LoadBalancer` service (Bonus 2). Kubernetes created it,
   so Terraform never knew about it. Delete manually.
2. **Unattached EBS volumes** in state `available`. You pay for these whether or not
   anything reads them.
3. **CloudWatch log groups.** EKS created `/aws/eks/<cluster>/cluster` for the control-plane
   logs we enabled. Terraform did not create it, so Terraform will not delete it. Storage is
   cheap but it is untidy:
   ```bash
   aws logs delete-log-group --log-group-name /aws/eks/<handle>-tflab-eks/cluster --region ap-south-1
   ```

---

## If destroy fails

| Error | Cause | Fix |
|---|---|---|
| `DependencyViolation` on a security group | an ELB is still using it | delete the ELB first, then retry |
| `BucketNotEmpty` | versioned objects remain | `force_destroy = true` is already set; if it still fails, empty the bucket in the console |
| `RepositoryNotEmptyException` | ECR has images | `force_delete = true` handles it; re-run |
| destroy hangs on the node group | nodes draining | wait — it can take 10 minutes |
| `Error: Kubernetes cluster unreachable` | you destroyed Lab 05 before Lab 06 | `terraform state rm` each stranded k8s resource in Lab 06, then destroy |

---

## Final sanity check

Open the **AWS Billing console → Cost Explorer**, filter to today, group by service. It
takes several hours to update, so also set a **budget alert at $5** before you leave. Every
engineer who has ever run a lab account has a story about the month they forgot.

---

## Checkpoint

- [ ] All six directories destroyed, in reverse order
- [ ] Zero EKS clusters, zero running instances, zero load balancers, zero available volumes
- [ ] A billing alert exists
