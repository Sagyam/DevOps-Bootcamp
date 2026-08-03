# Day 2 — ECR & EKS: Your Containers Move Into AWS

> **Today you will:** push an image to your own private registry (ECR), stand up a managed Kubernetes cluster (EKS), and deploy our old friend **podinfo** behind a real cloud load balancer. Everything you learned in the Kubernetes module, now on rented hardware.

⏱️ **Time warning:** EKS cluster creation takes **15–20 minutes**. We'll kick it off early and do ECR while it bakes.

💸 **Cost warning:** EKS charges for the control plane by the hour, plus the worker nodes. Today's cluster must be **deleted before you leave**. The cleanup section is not optional.

---

## 0. Setup

Tools needed today (in addition to the AWS CLI):

```bash
# kubectl — you have this from the Kubernetes module; verify:
kubectl version --client

# eksctl — the community-standard EKS bootstrapper
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# Docker running locally
docker version
```

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-south-1
```

---

## Part A — Start the EKS Cluster (then walk away)

We start this **first** because it takes ~20 minutes. Read Part B while it runs.

```bash
eksctl create cluster \
  --name bootcamp-YOURNAME \
  --region $AWS_REGION \
  --version 1.32 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 3 \
  --managed
```

While it runs, note what eksctl's log output shows it building: a dedicated **VPC** with public/private subnets, the **control plane** (managed by AWS — you never SSH into it), and a **managed node group** (plain EC2 instances that register as Kubernetes nodes — check the EC2 console mid-creation and you'll see them appear, just like your Day 1 instance).

> 🖥️ **GUI checkpoint (while waiting):** **EKS → Clusters → bootcamp-YOURNAME** (it will show "Creating"). Once up, explore:
> - **Compute** tab — the managed node group; this is where you'd change instance types or scaling limits in the GUI
> - **Networking** tab — the VPC/subnets eksctl made, and **cluster endpoint access** (public vs private API server — production clusters often go private-only)
> - **Add-ons** tab — vpc-cni, kube-proxy, CoreDNS: the plumbing AWS manages for you
> - **Update** button next to the Kubernetes version — this is where control-plane upgrades happen (one minor version at a time!)

---

## Part B — ECR (while the cluster bakes)

### B1. Create a repository

One ECR repository holds the tags of **one** image (like `docker.io/stefanprodan/podinfo`, but private and yours):

```bash
aws ecr create-repository \
  --repository-name bootcamp/podinfo \
  --image-scanning-configuration scanOnPush=true \
  --query 'repository.repositoryUri' --output text
```

Save the URI:

```bash
export ECR_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/bootcamp/podinfo
echo $ECR_URI
```

Notice the anatomy: `ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO` — the registry hostname encodes your account and region.

### B2. Log Docker into ECR

ECR uses your IAM identity, exchanged for a 12-hour Docker token:

```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

You should see `Login Succeeded`. (When a push mysteriously fails tomorrow with `no basic auth credentials` — the token expired; run this again.)

### B3. Tag and push podinfo

Pull the public image, re-tag it with your registry's name, push:

```bash
docker pull stefanprodan/podinfo:6.14.0

docker tag stefanprodan/podinfo:6.14.0 $ECR_URI:6.14.0
docker tag stefanprodan/podinfo:6.14.0 $ECR_URI:latest

docker push $ECR_URI:6.14.0
docker push $ECR_URI:latest
```

📝 **Remember from the Docker module:** a tag is just a pointer. Both pushes above upload the layers **once** — the second push says "Layer already exists" all the way down.

List what's there:

```bash
aws ecr describe-images \
  --repository-name bootcamp/podinfo \
  --query 'imageDetails[].{Tags:imageTags,SizeMB:imageSizeInBytes,Pushed:imagePushedAt}' \
  --output table
```

### B4. Vulnerability scanning

We enabled `scanOnPush` — see the results:

```bash
aws ecr describe-image-scan-findings \
  --repository-name bootcamp/podinfo \
  --image-id imageTag=6.14.0 \
  --query 'imageScanFindings.findingSeverityCounts'
```

> 🖥️ **GUI checkpoint:** **ECR → Repositories → bootcamp/podinfo → click the image digest**. The **Vulnerabilities** tab lists each CVE with severity and the package that carries it — same idea as the Trivy scans in our Harbor setup, but AWS-native. Also check repository **Permissions** (cross-account image pulls live here) and the **Lifecycle policy** tab.

### B5. Lifecycle policy — don't hoard old images

CI pipelines push constantly; registries bloat. Auto-expire untagged images:

```bash
cat > ecr-lifecycle.json <<'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name bootcamp/podinfo \
  --lifecycle-policy-text file://ecr-lifecycle.json
```

---

## Part C — EKS: Deploy Podinfo

### C1. Connect kubectl

eksctl already wrote your kubeconfig, but know the official command — you'll need it on any other machine:

```bash
aws eks update-kubeconfig --name bootcamp-YOURNAME --region $AWS_REGION

kubectl get nodes -o wide
kubectl get pods -A
```

Two `t3.medium` nodes, `Ready`. The `-o wide` output shows their **internal IPs** — cross-reference them in the EC2 console. They're just instances.

### C2. Deploy from *your* ECR

Same manifests you know from the Kubernetes module — only the image line changes:

```bash
cat > podinfo.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 2
  selector:
    matchLabels: { app: podinfo }
  template:
    metadata:
      labels: { app: podinfo }
    spec:
      containers:
        - name: podinfo
          image: $ECR_URI:6.14.0
          ports:
            - containerPort: 9898
          resources:
            requests: { cpu: 100m, memory: 64Mi }
            limits:   { cpu: 500m, memory: 256Mi }
          readinessProbe:
            httpGet: { path: /readyz, port: 9898 }
          livenessProbe:
            httpGet: { path: /healthz, port: 9898 }
---
apiVersion: v1
kind: Service
metadata:
  name: podinfo
spec:
  type: LoadBalancer
  selector: { app: podinfo }
  ports:
    - port: 80
      targetPort: 9898
EOF

kubectl apply -f podinfo.yaml
```

❓ **Why did the nodes get to pull from your *private* registry with no imagePullSecret?** Because eksctl's node role includes the ECR read-only policy — the nodes authenticate to ECR with their **IAM role**, exactly the Day 2 pattern. Machines get roles.

### C3. `type: LoadBalancer` finally means something

On our local clusters, `LoadBalancer` services sat in `<pending>` forever. On EKS, AWS provisions a real **Elastic Load Balancer**:

```bash
kubectl get svc podinfo -w
# wait until EXTERNAL-IP shows a long ...elb.amazonaws.com hostname, then Ctrl-C

export LB=$(kubectl get svc podinfo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $LB
```

DNS takes a couple of minutes to propagate, then:

```bash
curl http://$LB
```

Podinfo's JSON greeting, served from your cluster, through an AWS load balancer, from an image in your private registry. 🎉

> 🖥️ **GUI checkpoint:** **EC2 → Load Balancers**. Kubernetes created this for you! Open it:
> - **Listeners** — port 80 forwarding to the node port
> - **Target instances** / health checks — your worker nodes being probed
> - This mapping (Service object → cloud resource) is the "cloud controller" pattern; deleting the Service deletes the ELB. That is also why cleanup order matters tonight.

### C4. Scale and self-heal

```bash
# Scale up
kubectl scale deployment podinfo --replicas=4
kubectl get pods -o wide      # spread across both nodes

# Kill a pod, watch the Deployment replace it
kubectl delete pod $(kubectl get pods -l app=podinfo -o jsonpath='{.items[0].metadata.name}')
kubectl get pods
```

### C5. A rolling update through ECR

Push a "new version" (retag) and roll it out:

```bash
docker tag stefanprodan/podinfo:6.14.0 $ECR_URI:v2
docker push $ECR_URI:v2

kubectl set image deployment/podinfo podinfo=$ECR_URI:v2
kubectl rollout status deployment/podinfo
kubectl rollout history deployment/podinfo
```

The full loop — build → push to ECR → deploy to EKS — is exactly what your GitHub Actions pipeline automates in production.

---

## 🧹 Cleanup (MANDATORY — this is the expensive day)

**Order matters.** Delete the Service *first*, or the orphaned load balancer will block VPC deletion:

```bash
# 1. Delete k8s resources (removes the ELB)
kubectl delete -f podinfo.yaml

# 2. Delete the cluster (removes control plane, nodes, VPC — takes ~10 min)
eksctl delete cluster --name bootcamp-YOURNAME --region $AWS_REGION

# 3. Delete ECR repo and its images
aws ecr delete-repository --repository-name bootcamp/podinfo --force

rm -f podinfo.yaml ecr-lifecycle.json
```

Verify nothing survived:

```bash
aws eks list-clusters --output table
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output table
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output table 2>/dev/null
aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output table 2>/dev/null
```

All empty? You're free to go. 🏁

---

## ✅ Day 3 Checklist

- [ ] Created an ECR repository with scan-on-push
- [ ] Authenticated Docker to ECR via IAM
- [ ] Tagged and pushed podinfo; read the vulnerability scan
- [ ] Set an ECR lifecycle policy
- [ ] Created an EKS cluster with eksctl and connected kubectl
- [ ] Deployed from a private registry with zero imagePullSecrets (role-based pulls)
- [ ] Exposed a Service via a real cloud LoadBalancer
- [ ] Performed a rolling update via a new ECR tag
- [ ] Deleted **everything**, in the right order

## 🏠 Homework

1. In your own words (5–6 sentences): trace the path of an HTTP request from your browser to a podinfo pod today. Name every AWS/Kubernetes component it passed through.
2. Our local clusters were "free"; EKS is not. List the three separately-billed things today's lab created, and which single command deleted each.
