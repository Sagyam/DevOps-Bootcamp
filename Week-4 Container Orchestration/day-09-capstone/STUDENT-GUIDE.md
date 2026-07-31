# Chiya Shop — Kubernetes capstone

Today you build and run a six-component system. Not a toy: a frontend, two APIs, a
highly-available Postgres cluster managed by an operator, a Valkey queue on a StatefulSet,
and an API gateway doing TLS, routing, compression and rate limiting.

You will write almost no YAML from scratch. That is deliberate. The skill you are
practising today is **consuming** infrastructure, which is what the job actually is.

Work through this in order. There are checkpoints marked ✅ — do not move past one until it
passes.

---

## What you are building

```
                        Browser
                           │
                           ▼
  ┌──────────── chiya-edge ─────────────┐
  │  Traefik   TLS · routing · gzip     │        control-plane node
  │            rate limiting · logs     │
  └──────────────────┬──────────────────┘
                     ▼
  ┌──────────── chiya-app ──────────────┐
  │  chiya-web    static site, nginx    │        tier=app nodes
  │  orders-api   Go, write path        │
  │  kitchen-api  Node, worker + HPA    │
  └──────────────────┬──────────────────┘
                     ▼
  ┌──────────── chiya-data ─────────────┐
  │  chiya-db     3 Postgres pods       │        tier=data node
  │               managed by an operator│        (tainted)
  │  valkey       StatefulSet, by hand  │
  └─────────────────────────────────────┘
                     ▲
  ┌──────────── cnpg-system ────────────┐
  │  CloudNativePG operator             │
  └─────────────────────────────────────┘
```

Three stages, three registries' worth of artifacts:

| Stage | You do | GitHub Actions produces |
|---|---|---|
| **1** | Push `apps/` | three container images in GHCR |
| **2** | Push `charts/` | five Helm charts in the same GHCR |
| **3** | `helm install` from GHCR | the running system above |

---

## Pre-flight

### Tools

```bash
minikube version     # v1.34+
kubectl version --client
helm version         # v3.14+ (OCI registry support)
docker version
git --version
```

Optional but strongly recommended:

```bash
k9s version          # you will live in this today
hey                  # load generator; a curl fallback is provided
```

### Resources

| Laptop RAM | Command | Notes |
|---|---|---|
| 16 GB+ | `./platform/bootstrap.sh` | 3 nodes, full topology |
| 8 GB | `NODES=2 MEM=2200 ./platform/bootstrap.sh` | 2 nodes, taint demo still works |
| 8 GB, struggling | also set `postgres.instances=2` in stage 3 | |

## Stage 0 — the cluster

The platform layer is not your application. An app team should never have to install an
operator or a gateway — but today you are both teams, so you install it once.

```bash
git clone <the repo URL your instructor gave you> chiya-shop
cd chiya-shop

./platform/bootstrap.sh
```

That script does seven things. Read them as they scroll past:

1. starts a 3-node minikube profile called `chiya`
2. labels the nodes `tier=app` / `tier=data` and **taints** the data node
3. enables `metrics-server` (the HPA is dead without it), storage class, provisioner
4. creates `chiya-app`, `chiya-data`, `chiya-edge` plus a `ResourceQuota`
5. installs the **CloudNativePG operator**
6. installs **Traefik** from one values file
7. mints a self-signed TLS certificate

**✅ Checkpoint 0**

```bash
kubectl get nodes -L tier -L ingress-ready
kubectl top nodes                       # must return numbers, not an error
kubectl get crd | grep cnpg             # the operator taught the API server new nouns
kubectl -n chiya-edge get pods          # traefik Running
```

If `kubectl top nodes` errors, stop. Nothing about the HPA will work. See troubleshooting.

> **Notice what just happened in step 5.** You installed a program, and the Kubernetes API
> server grew new resource types: `clusters.postgresql.cnpg.io`, `backups`, `poolers`.
> `kubectl explain cluster.spec.instances` now works. Hold that thought until §5.

---

## Stage 1 — source becomes images

### 1.1 Make the repo yours

Create a **new, empty, public** repository on GitHub. Then:

```bash
./platform/set-owner.sh <your-github-username>

git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/<your-username>/chiya-shop.git
git add -A
git commit -m "chiya shop capstone"
git push -u origin main
```

`set-owner.sh` lowercases your username for you. **OCI reference names must be lowercase**
and GitHub usernames often are not — this single detail causes more failed builds in this
lab than everything else combined.

### 1.2 Watch the pipeline

Open the Actions tab. `build-images` runs a **matrix** of three jobs, one per app, and
pushes each to `ghcr.io/<you>/<app>` with two tags: the commit SHA and `latest`.

Three languages, three Dockerfiles, one workflow:

- `chiya-web` — static HTML on `nginx:alpine`, no build step, ~15 seconds
- `orders-api` — Go, multi-stage into `distroless/static`, final image ~12 MB
- `kitchen-api` — Node 22 on Alpine

### 1.3 Make the packages public ← **everyone gets stuck here**

GHCR packages are **private by default**. Your cluster cannot pull them.

For each of the three packages:

> your GitHub profile → **Packages** → click the package → **Package settings**
> → scroll to **Danger Zone** → **Change visibility** → **Public**

**✅ Checkpoint 1** — from a terminal with no GitHub credentials:

```bash
docker logout ghcr.io
docker pull ghcr.io/<your-username>/orders-api:latest
```

If that works, stage 1 is done.

---

## Stage 2 — charts become artifacts

A Helm chart is just a tarball of templates plus a values contract. Since Helm 3.8 an OCI
registry can hold them, which means **the same registry holds your images and your
deployment logic**. One credential, one place, one access-control model.

### 2.1 Look before you push

```bash
ls charts/
#  chiya-web  orders-api  kitchen-api  chiya-data  chiya-stack

cat charts/chiya-stack/Chart.yaml
```

`chiya-stack` is an **umbrella chart**. It contains almost no templates of its own — just
three dependencies and the Traefik routing policy. Installing it installs everything.

Open `charts/chiya-data/values.yaml` and read the comment at the top. It explains the most
important idea in this lab.

### 2.2 Push

Touch anything under `charts/` and push:

```bash
git commit --allow-empty -m "publish charts"
git push
```

The `publish-charts` workflow has two jobs:

- **leaves** — lints and pushes `chiya-web`, `orders-api`, `kitchen-api`, `chiya-data`
- **umbrella** — `needs: leaves`, then resolves dependencies and pushes `chiya-stack`

The `needs:` is not decoration. `helm dependency update` on the umbrella will fail if the
leaf charts do not already exist in the registry. Chicken, egg.

### 2.3 Public again

Charts land at `ghcr.io/<you>/charts/<chart-name>` and **each one is a separate GHCR
package needing its own visibility flip.** Five of them. Yes, again.

**✅ Checkpoint 2**

```bash
helm registry logout ghcr.io 2>/dev/null || true
helm show chart oci://ghcr.io/<your-username>/charts/chiya-stack --version 0.1.0
```

---

## Stage 3 — consume everything

### 3.1 The data layer

```bash
export OWNER=<your-username>

helm install chiya-data oci://ghcr.io/$OWNER/charts/chiya-data \
  --version 0.1.0 -n chiya-data

kubectl -n chiya-data get cluster -w
```

You are watching a **custom resource** with `kubectl get -w`, exactly like a Deployment.
It goes `Setting up primary` → `Creating a new replica` → `Cluster in healthy state`.
Give it two to four minutes on a laptop.

While you wait, in another pane:

```bash
kubectl -n chiya-data get pods -o wide
kubectl -n chiya-data get pvc
kubectl -n chiya-data get svc
kubectl -n chiya-data get statefulset
```

**Stop and look at that last one.** There is a StatefulSet for `valkey` and *none* for
Postgres. Three Postgres pods, three PVCs, automatic failover — and no StatefulSet
anywhere. CloudNativePG manages bare Pods with its own controller, because a StatefulSet's
ordinal rolling update is the wrong model for a database that needs
switchover-*then*-restart ordering.

This is the single best argument for operators you will see today: an operator is not a
fancier Deployment. It is domain knowledge, running in a loop.

Also look at the Services: `chiya-db-rw`, `chiya-db-ro`, `chiya-db-r`. The operator moves a
label between pods on failover, and `-rw` follows the primary. Your application never
learns a new hostname.

### 3.2 Move the Secret across the namespace boundary

```bash
kubectl -n chiya-data get secret chiya-db-app -o jsonpath='{.data}' | head -c 200; echo
```

The operator generated a password. Nobody typed it, nobody committed it. But that Secret
lives in `chiya-data`, and your APIs run in `chiya-app`:

```bash
./platform/copy-db-secret.sh
```

**Think about why Kubernetes refuses to do this for you.** A Secret that leaks across
namespaces makes namespaces worthless as a security boundary. In production this seam is
filled by External Secrets Operator, Reflector, or kubernetes-replicator — never by hand.

### 3.3 The application

```bash
helm install chiya oci://ghcr.io/$OWNER/charts/chiya-stack \
  --version 0.1.0 -n chiya-app -f values-dev.yaml

kubectl -n chiya-app get pods -w
```

Watch the ordering. A **Job** runs first — that is a Helm `pre-install` hook applying the
database schema. Only when it succeeds do the application pods roll. Schema before code,
enforced by the packaging system.

```bash
echo "https://$(minikube -p chiya ip):30443"
```

Open it. Accept the self-signed certificate warning. Order a chiya.

> **macOS / Windows users:** the docker-driver IP is not routable from your host. Run
> `minikube -p chiya service traefik -n chiya-edge --url` in a spare terminal and use the
> HTTPS URL it prints instead.

**✅ Checkpoint 3** — the UI shows an order moving `queued` → `cooking` → `ready`, with a
`served by` pod name. That single row proves the whole chain: gateway → API → Postgres →
Valkey → worker → Postgres → API → gateway.

### 3.4 The punchline

```bash
helm upgrade chiya oci://ghcr.io/$OWNER/charts/chiya-stack \
  --version 0.1.0 -n chiya-app -f values-prod.yaml
```

Open k9s (`k9s -n chiya-app`) and just watch for thirty seconds.

Same charts. Same images. Same cluster. **One different file**, and you now have:

- 3 frontend replicas spread across nodes
- 4 `orders-api` replicas with *required* anti-affinity
- an HPA on `kitchen-api`
- PodDisruptionBudgets
- gzip on every response
- a rate limiter at the edge

And some `orders-api` pods are stuck **Pending**. That is not a bug — read on.

---

## Part 4 — experiments

Do these in order. Each one is a concept you learned this month, doing something real.

### 4.1 Anti-affinity: the scheduler tells the truth

```bash
kubectl -n chiya-app get pods -l app.kubernetes.io/name=orders-api -o wide
kubectl -n chiya-app describe pod <one-of-the-Pending-ones> | tail -20
```

You asked for 4 replicas that must not share a node, and you have 2 app nodes. The
scheduler is not failing — it is refusing to lie to you about your capacity.

Now soften it and watch them all schedule:

```bash
helm upgrade chiya oci://ghcr.io/$OWNER/charts/chiya-stack --version 0.1.0 \
  -n chiya-app -f values-prod.yaml --set orders-api.antiAffinity.mode=preferred
```

`required` = correctness. `preferred` = availability. Both are right, for different systems.

### 4.2 Taints: keeping the wrong workloads out

```bash
kubectl -n chiya-app run nosy --image=nginx:1.27-alpine \
  --overrides='{"spec":{"nodeSelector":{"tier":"data"}}}'

kubectl -n chiya-app describe pod nosy | grep -A3 Events
```

`had untolerated taint {tier: data}`. The node said no. Now let it in:

```bash
kubectl -n chiya-app delete pod nosy
kubectl -n chiya-app run nosy --image=nginx:1.27-alpine --overrides='{
  "spec":{"nodeSelector":{"tier":"data"},
  "tolerations":[{"key":"tier","operator":"Equal","value":"data","effect":"NoSchedule"}]}}'
kubectl -n chiya-app get pod nosy -o wide
kubectl -n chiya-app delete pod nosy
```

**nodeSelector is the pod choosing a node. A taint is the node choosing pods.** You need
both, and they are not the same mechanism.

### 4.3 HPA under real load

Two panes. First:

```bash
kubectl -n chiya-app get hpa,pods -w
```

Second:

```bash
./platform/loadtest.sh
```

(or click *Send load* in the web UI). Watch `kitchen-api` climb from 2 toward 10.

Then **stop the load and stay watching.** `scaleDownWindow` is set to 60 seconds so you
actually see it come back down. Default is 300 — most people never witness a scale-down
because they walk away.

```bash
kubectl -n chiya-app describe hpa kitchen-api | tail -15
```

### 4.4 RBAC: the pod that asks who else is running

The Fleet panel in the UI is `kitchen-api` calling the Kubernetes API with its own
ServiceAccount token. No client library — just `fetch()` with a bearer token read from
`/var/run/secrets/kubernetes.io/serviceaccount/token`.

Break it:

```bash
kubectl -n chiya-app delete rolebinding kitchen-api-pod-reader
```

Refresh the page. The Fleet panel now says 403. Check from the outside:

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:chiya-app:kitchen-api -n chiya-app
# no
```

Put it back:

```bash
helm upgrade chiya oci://ghcr.io/$OWNER/charts/chiya-stack --version 0.1.0 \
  -n chiya-app -f values-prod.yaml
kubectl auth can-i list pods --as=system:serviceaccount:chiya-app:kitchen-api -n chiya-app
# yes
```

`kubectl auth can-i --as=...` is the most useful RBAC debugging command that exists.
Memorise it.

### 4.5 The gateway: 429 from six lines of YAML

`values-prod.yaml` already enabled the rate limiter. Prove it:

```bash
BASE="https://$(minikube -p chiya ip):30443"
for i in $(seq 1 40); do
  curl -sk -o /dev/null -w "%{http_code} " -X POST "$BASE/api/orders" \
    -H 'Content-Type: application/json' -d '{"flavour":"Masala chiya","qty":1}'
done; echo
```

You will see `201`s turn into `429`s. Turn it off and the 429s vanish:

```bash
helm upgrade chiya oci://ghcr.io/$OWNER/charts/chiya-stack --version 0.1.0 \
  -n chiya-app -f values-prod.yaml --set gateway.rateLimit.enabled=false
```

```bash
kubectl -n chiya-app get middleware,ingressroute
kubectl -n chiya-edge logs deploy/traefik | tail -20     # access logs, free
```

Compression is on too — check `Content-Encoding: gzip`:

```bash
curl -skI -H 'Accept-Encoding: gzip' "$BASE/" | grep -i content-encoding
```

> **One honest gap.** Open-source Traefik has **no response cache**. Kong and Apache APISIX
> ship one as a built-in plugin. Choosing a gateway is a real architectural decision, not a
> coin flip — and knowing where your tool stops is part of knowing the tool.

### 4.6 Postgres failover — the best five minutes of the day

Pane one, a heartbeat:

```bash
BASE="https://$(minikube -p chiya ip):30443"
while true; do curl -sk -o /dev/null -w "%{http_code} " "$BASE/api/orders"; sleep 1; done
```

Pane two, find and kill the primary:

```bash
kubectl -n chiya-data get pods -l cnpg.io/instanceRole=primary
kubectl -n chiya-data delete pod <that-primary-pod>
kubectl -n chiya-data get cluster -w
```

A short blip, then 200s resume. **Nobody changed a connection string.** The app talks to
`chiya-db-rw`; the operator moved that label to the new primary and the Service followed.

That behaviour — detect, promote, re-point, heal — is roughly 40,000 lines of Postgres
domain knowledge that you consumed with one `helm install`.

### 4.7 StatefulSet: identity is not clustering

```bash
kubectl -n chiya-data scale statefulset valkey --replicas=3
kubectl -n chiya-data get pods -l app.kubernetes.io/name=valkey -w
```

Created in order: `valkey-0`, then `-1`, then `-2`. Each with its own PVC:

```bash
kubectl -n chiya-data get pvc
kubectl -n chiya-data run dns --rm -it --image=busybox:1.36 --restart=Never \
  -- nslookup valkey-1.valkey.chiya-data.svc.cluster.local
```

Stable name, stable storage, stable DNS. **And they are three completely unrelated Valkey
servers.** A StatefulSet gives you identity. It does not give you replication, leader
election, failover, or resharding. Somebody has to write that — and that somebody is an
operator. This is exactly why Postgres got one and this did not.

```bash
kubectl -n chiya-data scale statefulset valkey --replicas=1
kubectl -n chiya-data get pvc     # the extra PVCs are still there. Deliberately.
```

### 4.8 Namespace as a boundary

```bash
kubectl -n chiya-app describe quota chiya-app-quota
kubectl -n chiya-app scale deploy chiya-web --replicas=20
kubectl -n chiya-app get events --sort-by=.lastTimestamp | tail -5
```

The ReplicaSet controller will tell you exactly which limit it hit. Scale back:

```bash
kubectl -n chiya-app scale deploy chiya-web --replicas=3
```

### 4.9 ConfigMap without a rebuild

```bash
helm upgrade chiya oci://ghcr.io/$OWNER/charts/chiya-stack --version 0.1.0 \
  -n chiya-app -f values-prod.yaml \
  --set chiya-web.config.tagline="भोलि फेरि आउनुहोस्"
```

The frontend text changes. No image was rebuilt, no CI ran, no commit was made. The chart
has a `checksum/config` annotation so the pods roll automatically when the ConfigMap
content changes — a trick worth stealing.

### 4.10 Zero-downtime rolling update

Keep the heartbeat loop from 4.6 running:

```bash
kubectl -n chiya-app rollout restart deploy/orders-api
kubectl -n chiya-app rollout status deploy/orders-api
```

Not a single non-200, because `maxUnavailable: 0` plus a real readiness probe means a pod
only receives traffic once it has proven it can reach the database.

---

## Part 5 — extend the API itself (bonus)

Everything so far consumed somebody else's custom resources. Now make your own.

```bash
kubectl apply -f platform/crd-chiyaspecial.yaml
kubectl apply -f platform/chiyaspecial-sample.yaml

kubectl -n chiya-app get chiyaspecials
kubectl -n chiya-app get cs                    # the short name works
kubectl explain chiyaspecial.spec.spiceLevel   # so does explain
```

Open k9s and type `:chiyaspecials`. It is there, with columns, watchable, RBAC-able.

Now try to break it:

```bash
kubectl -n chiya-app apply -f - <<'EOF'
apiVersion: chiya.example.com/v1alpha1
kind: ChiyaSpecial
metadata: { name: too-cheap }
spec: { flavour: "Free chiya", priceNpr: 2 }
EOF
```

Rejected — the API server validated your object against the OpenAPI schema in the CRD.
You wrote **zero lines of code** and got storage, validation, versioning, a REST API,
authorisation, audit logging, and tooling support.

Then run the world's smallest operator:

```bash
./platform/tiny-operator.sh          # ctrl-c to stop
```

In another pane, edit a special (`kubectl -n chiya-app edit cs masala`) and watch the
reconciler notice and update the ConfigMap it manages.

Read desired state → read actual state → make them match → repeat. That is *all* an
operator is. CloudNativePG is that same loop plus a decade of Postgres expertise.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `unauthorized` on `docker pull` / `helm pull` | GHCR package is private | Package settings → Change visibility → Public. Every package, separately. |
| `invalid reference format` in CI | uppercase in your GitHub username | run `./platform/set-owner.sh` and push again |
| HPA shows `<unknown>/60%` | metrics-server missing or not ready | `minikube -p chiya addons enable metrics-server`, then wait; verify with `kubectl top pods` |
| Pod stuck `Pending` | quota, taint, or required anti-affinity | `kubectl describe pod <name>` — the Events block always names the reason |
| PVC stuck `Pending` | storage addon off | `minikube -p chiya addons enable storage-provisioner default-storageclass` |
| `chiya-db` never leaves `Setting up primary` | data node out of memory | drop to `--set postgres.instances=2`, or restart minikube with more memory |
| API pods `CrashLoopBackOff` with auth errors | Secret not copied into `chiya-app` | `./platform/copy-db-secret.sh` then `kubectl -n chiya-app rollout restart deploy` |
| Traefik returns 404 | IngressRoute is in a different namespace from the Services | both must be in `chiya-app` |
| Cannot reach `https://<minikube-ip>:30443` | macOS/Windows docker driver | `minikube -p chiya service traefik -n chiya-edge --url` |
| Pods on different nodes cannot talk | multi-node CNI trouble | `minikube delete -p chiya` then `minikube start -p chiya --nodes 3 --cni=flannel` |
| `helm dependency update` fails | leaf charts not published yet, or `REPLACE_ME` still present | check the `leaves` job succeeded; re-run `set-owner.sh` |

Universal first move, in this order:

```bash
kubectl -n <ns> get pods
kubectl -n <ns> describe pod <name>     # read the Events at the bottom
kubectl -n <ns> logs <name> --previous  # what it said before it died
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

---

## Cleanup

```bash
helm -n chiya-app uninstall chiya
helm -n chiya-data uninstall chiya-data
kubectl -n chiya-data delete pvc --all       # StatefulSet PVCs are never auto-deleted
minikube delete -p chiya
```

---

## Where you actually are

Count what you deployed today: an HA database with automatic failover, horizontal
autoscaling, TLS termination, rate limiting, compression, zero-downtime deploys, scheduled
jobs, least-privilege service identity, and a custom API type. Ten years ago that was a
team with a runbook. Today it was a handful of values files.

Now open **[landscape.cncf.io](https://landscape.cncf.io)** and let the wall of logos land.
The point is not that you should learn all of it. The point is that every box on that wall
is somebody's solved problem — and you now know how to consume one.

Group them by the question they answer:

- **What runs the container?** containerd, CRI-O, Kubernetes
- **How does it get there?** Helm, Argo CD, Flux
- **How does traffic move?** Envoy, Cilium, Istio, Linkerd, CoreDNS, Gateway API
- **What is it doing?** Prometheus, OpenTelemetry, Jaeger, Fluentd, OpenCost
- **Is it allowed to?** Falco, OPA, Kyverno, cert-manager, SPIFFE/SPIRE
- **How much of it should there be?** KEDA, Knative
- **Where does the data live?** etcd, Rook, Longhorn, Vitess, TiKV, **CloudNativePG**
- **Can I trust the artifact?** Harbor, Sigstore, Dragonfly, in-toto
- **How do humans use it?** Backstage, Crossplane, Dapr, KubeVirt
- **Does it survive?** Chaos Mesh, LitmusChaos

You used one of these as a black box today and it worked. That is the normal experience,
and it is the whole point.
