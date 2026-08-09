# Lab 02 — Terraform Manages Your Minikube Cluster

Same four commands as Lab 01. The only thing that changed is the provider: instead of
writing files, Terraform now makes calls to the Kubernetes API server. If Lab 01 clicked,
this lab should feel *boringly familiar* — that's the point.

## What you'll learn

- Providers are interchangeable backends for the same workflow
- HCL resources map 1:1 to Kubernetes objects you already know from YAML
- Drift detection against a **live system** that can change without you

## Step 0 — Start the cluster

```bash
minikube start
kubectl config current-context   # must say: minikube
```

## Step 1 — Read before you run

Open `main.tf` next to a Deployment YAML you've written before. Same fields, different
syntax: `kind: Deployment` became `resource "kubernetes_deployment_v1"`, `metadata:` became
a `metadata {}` block. Terraform is not replacing Kubernetes — it's another client of the
same API, like kubectl with memory.

## Step 2 — The loop

```bash
terraform init
terraform plan     # 4 resources: namespace, configmap, deployment, service
terraform apply
```

Verify with the tools you already trust:

```bash
kubectl get all -n tf-lab
minikube service podinfo -n tf-lab --url   # open in browser: teal podinfo UI
```

## Step 3 — Declarative scaling

```bash
terraform apply -var="replicas=4"
kubectl get pods -n tf-lab -w
```

One field changed in the plan (`replicas: 2 -> 4`). Terraform PATCHed the Deployment; the
Deployment controller did the actual pod math. Two reconciliation loops, cooperating.

## Step 4 — Drift, live-system edition

Someone "fixes production" with kubectl at 2am:

```bash
kubectl scale deployment podinfo -n tf-lab --replicas=1
terraform plan
```

Terraform sees `1`, wants `4`, plans the correction. `terraform apply` restores order.

**Discussion:** in Lab 01, drift only happened when *you* touched the files. Here, HPAs,
operators, and colleagues can all cause drift. Who should win? (This is why real teams
either ignore `replicas` in Terraform with `lifecycle { ignore_changes }` when an HPA
owns it, or ban kubectl edits entirely — GitOps in one sentence.)

## Step 5 — Change the app version

```bash
terraform apply -var="app_version=6.13.0"
kubectl rollout status deployment/podinfo -n tf-lab
```

Terraform changed the image tag; Kubernetes ran the rolling update. Division of labor again.

## Step 6 — Destroy

```bash
terraform destroy
kubectl get ns tf-lab   # NotFound
```

## Checkpoint questions

1. Why does the ConfigMap get created before the Deployment? Find the reference in `main.tf`.
2. `terraform.tfstate` now contains cluster objects. If you `minikube delete` and recreate
   the cluster, what will `terraform plan` say? Why?
3. When would you *not* want Terraform managing Kubernetes objects? (Hint: how does your
   CI/CD pipeline deploy new image tags?)
