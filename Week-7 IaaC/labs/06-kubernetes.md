# Lab 06 — Kubernetes Resources via Terraform

**Time: 25 minutes** · `code/06-kubernetes/`

The cluster exists. Now deploy to it — from Terraform, not `kubectl apply`.

---

## Steps

```bash
cd ../06-kubernetes
cp terraform.tfvars.example terraform.tfvars
```

Edit it: your handle, and the `cluster_name` from Lab 05's output.

```bash
terraform init
terraform apply
```

Then, in a **second terminal**:

```bash
kubectl -n <handle>-app port-forward svc/podinfo 8080:80
```

Open <http://localhost:8080>. You should see podinfo, in orange, with your name on it.

---

## Part A — The chicken-and-egg problem

This is the single most important thing in this lab, and it catches everyone.

A `provider` block is configured during **plan**. The `kubernetes` provider needs a cluster
endpoint and a CA certificate. If the cluster that provides them is created in the *same*
apply, then at plan time those values are `(known after apply)` — and Terraform cannot
configure a provider from unknown values.

Symptoms range from a confusing error to a corrupted plan that half-applies.

**The fix used here:** this is a separate root module with its own state. Lab 05 built the
cluster; we read it back with a data source:

```hcl
data "aws_eks_cluster" "this" { name = var.cluster_name }
```

Two root modules, one dependency, no cycle. This is why "one giant Terraform directory"
is an anti-pattern — the cluster and the things running on it belong in different states.

---

## Part B — Authentication: `exec`, not a token

```hcl
exec {
  api_version = "client.authentication.k8s.io/v1beta1"
  command     = "aws"
  args        = ["eks", "get-token", "--cluster-name", var.cluster_name, ...]
}
```

The tempting alternative is `data "aws_eks_cluster_auth"`, which returns a token. It works,
and then bites you twice: the token is valid for 15 minutes (long applies fail halfway),
and it gets **written into your state file**.

`exec` shells out for a fresh token on every API call. Nothing sensitive is persisted.
Same config on every OS, as long as `aws` is on your PATH.

---

## Part C — Config changes that actually take effect

```hcl
annotations = {
  "config-hash" = sha256(jsonencode(kubernetes_config_map.app.data))
}
```

Kubernetes does **not** restart pods when a ConfigMap changes. Your new config sits in etcd
while every pod keeps running the old values, and you spend twenty minutes wondering why
your change did nothing.

Hashing the ConfigMap into a pod annotation changes the pod template, which triggers a
rolling update. Try it — edit `PODINFO_UI_COLOR` to `#2dd4bf`, then:

```bash
terraform apply
kubectl -n <handle>-app get pods -w
```

Watch the rollout. Refresh the browser: teal.

---

## Part D — Resource requests and limits

```hcl
requests = { cpu = "50m", memory = "64Mi" }
limits   = { memory = "256Mi" }
```

Note there is **no CPU limit**, on purpose. Memory limits are essential — exceeding memory
gets your pod OOMKilled and there is no graceful degradation. CPU limits, by contrast,
cause CFS throttling: your pod gets paused mid-request even when the node is idle. The
common guidance is *always set memory limits, rarely set CPU limits.*

Requests are what the scheduler uses to place pods. Set them too high and you waste money;
omit them entirely and the scheduler packs pods onto nodes until everything is unstable.

---

## Part E — Terraform or kubectl?

Honest answer: **both, for different things.**

| Use Terraform for | Use kubectl / GitOps for |
|---|---|
| the cluster itself | application deployments |
| namespaces, quotas, RBAC | anything that deploys many times per day |
| cluster-wide add-ons (controllers, operators) | anything a developer should change without an apply |
| things with AWS dependencies (IRSA roles) | CRDs and their instances |

The failure mode is putting a fast-moving app deployment in Terraform: now every code
release needs an `apply` against state that also contains your VPC. Terraform's blast
radius is wrong for that job. Argo CD or Flux is the right tool.

---

## Bonus 1 — Deploy your ECR image

In `terraform.tfvars`, set:

```hcl
app_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/<handle>/podinfo:6.7.0"
```

`terraform apply`, then `kubectl -n <handle>-app get pods`. It pulls with **no imagePullSecret**
— the node's IAM role carries `AmazonEC2ContainerRegistryReadOnly` from Lab 05. That is the
whole point of running in AWS: identity comes from the instance, not from a stored password.

## Bonus 2 — A real load balancer

Change the service `type` to `"LoadBalancer"` and apply. It will provision — but hang in
`<pending>`, because default-VPC subnets lack the tag AWS looks for. Fix it by managing a
tag on a subnet you do not own:

```hcl
data "aws_vpc" "default" { default = true }

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ec2_tag" "elb" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
```

(Add those two data sources to `main.tf` — this module does not have them yet.)

`aws_ec2_tag` is the escape hatch for tagging resources managed elsewhere. **Delete the load
balancer before you leave** — see Lab 07.

---

## Checkpoint

- [ ] podinfo reachable on localhost:8080 with your name on it
- [ ] You can explain the provider chicken-and-egg problem and its fix
- [ ] You changed the ConfigMap and saw a rolling restart
- [ ] You can argue when *not* to manage Kubernetes objects with Terraform
