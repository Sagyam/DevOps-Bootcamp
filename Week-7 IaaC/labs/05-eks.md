# Lab 05 — Terraform the EKS Cluster

**Time: 45 minutes (of which ~15 is waiting)** · `code/05-eks/`

The headline lab. We build a Kubernetes control plane and a managed node group from raw
resources — no community module — so you can see exactly what EKS is made of.

---

## Start the apply FIRST, then read

The control plane takes 9–12 minutes to provision and the node group another 3–4. So kick
it off now and read the rest of this document while AWS works.

```bash
cd ../05-eks
cp terraform.tfvars.example terraform.tfvars   # edit your handle
terraform init
terraform plan
terraform apply
```

Confirm with `yes`, then **leave the terminal running** and read on.

---

## Part A — Why no module?

`terraform-aws-modules/eks/aws` is excellent and you will use it at work. It is also ~4,000
lines that turn EKS into a black box. Today we use raw resources, because the whole cluster
is only five kinds of thing:

```
aws_iam_role          x2   <- control plane role, node role
aws_iam_role_policy_attachment
aws_eks_cluster       x1   <- the control plane
aws_eks_node_group    x1   <- the workers
(subnets, read via data source)
```

That is it. Once you have written it once, the module stops being magic and becomes a
convenience.

---

## Part B — Two roles again

Open `iam.tf`. This is Lab 02's lesson, reused:

| Role | Trusted principal | Why |
|---|---|---|
| cluster role | `eks.amazonaws.com` | the control plane calls EC2 APIs to manage ENIs, ELBs |
| node role | `ec2.amazonaws.com` | the workers are EC2 instances |

The node role gets three managed policies, and each has a job:

- `AmazonEKSWorkerNodePolicy` — lets the kubelet register with the cluster
- `AmazonEKS_CNI_Policy` — lets the VPC CNI attach ENIs and hand out pod IPs
- `AmazonEC2ContainerRegistryReadOnly` — **this is why your nodes can pull from Lab 04's ECR**

Note the `for_each` over a `toset([...])` — that is how you attach N policies without
writing N nearly-identical resource blocks.

Also note this:

```hcl
depends_on = [aws_iam_role_policy_attachment.cluster]
```

Terraform infers dependencies from references, and the cluster references the *role*, not
the *attachment*. Without the explicit `depends_on`, Terraform can create the cluster
before the role has permissions, and AWS returns an error that tells you nothing useful.
**Explicit `depends_on` is for the dependencies Terraform cannot see.**

---

## Part C — The auth model

```hcl
access_config {
  authentication_mode                         = "API"
  bootstrap_cluster_creator_admin_permissions = true
}
```

Historically, "who can talk to this cluster" lived in a ConfigMap called `aws-auth` inside
the cluster itself. Editing it wrongly locked you out of your own cluster permanently, with
no recovery path. It was, by consensus, the worst part of EKS.

`authentication_mode = "API"` moves that mapping into the AWS API, where it is a normal
resource you can Terraform (`aws_eks_access_entry`). Use this on every new cluster.

`bootstrap_cluster_creator_admin_permissions = true` makes whoever runs `terraform apply`
a cluster admin. Convenient for a lab; in production, an explicit `aws_eks_access_entry`
per team is better.

---

## Part D — Networking shortcuts we took (and why they're wrong)

We used the **default VPC**. Its subnets are public and auto-assign public IPs, which means
our nodes reach the internet directly and we need **no NAT Gateway**. That saves ~$32/month
and about three minutes of apply time.

It is also not how you run production. A real cluster has:

- private subnets for nodes, public subnets only for load balancers
- a NAT Gateway (or VPC endpoints for ECR/S3/STS, which is cheaper)
- subnets tagged `kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb`
- `endpoint_public_access = false`, or at minimum a CIDR allowlist

Being able to name the shortcut you took is more valuable than not taking it.

---

## Part E — `ignore_changes` on desired_size

```hcl
lifecycle {
  ignore_changes = [scaling_config[0].desired_size]
}
```

In production, Cluster Autoscaler or Karpenter changes the node count at runtime. Terraform
would see 5 nodes where its config says 2, and scale you back down — possibly during your
traffic peak. `ignore_changes` says "I set the initial value, something else owns it now."

This is the general shape of every Terraform-vs-runtime-controller conflict.

---

## Part F — When the apply finishes

```bash
terraform output kubeconfig_command
```

Run the command it prints — identical on Windows, macOS and Linux:

```bash
aws eks update-kubeconfig --name <handle>-tflab-eks --region ap-south-1
```

Then:

```bash
kubectl get nodes
kubectl get pods -A
```

You should see 2 `Ready` nodes and the default add-ons: `coredns`, `kube-proxy` and
`aws-node` (the VPC CNI). EKS installs those automatically — you did not have to.

> **`kubectl get nodes` hangs or says "couldn't get current server API group list"?**
> Your AWS credentials are not being found by the exec plugin. Run
> `aws sts get-caller-identity` again in the *same* terminal. On Windows this is usually
> a PowerShell-vs-Git-Bash mismatch: the profile is set in one shell and not the other.

---

## Checkpoint

- [ ] `kubectl get nodes` shows 2 Ready nodes
- [ ] You can list the five resource types that make up an EKS cluster
- [ ] You can explain why `depends_on` was needed on the cluster
- [ ] You can name two things about our networking that are wrong for production

## Stretch

Add an `aws_eks_addon` resource for `aws-ebs-csi-driver` so the cluster can provision
PersistentVolumes. Or change `capacity_type` to `"SPOT"` and watch the node group replace
itself for roughly 70% less money.
