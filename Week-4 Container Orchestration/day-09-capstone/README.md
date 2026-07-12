# Day 9 — Capstone: Deploy, Secure & Debug a Real Stack

**Time:** ~3.5 hours · **Today you prove the whole week.** You'll deploy a complete multi-service application, lock it down with RBAC, and then repair a deliberately broken copy that contains **one bug from every day** you've studied.

> Full cluster needed: metrics-server + ingress addons on, a few GB of memory free. `kubectl get nodes` and `kubectl top nodes` should both work.

---

## The app: ShortLink

```
                    Ingress
      shortlink.local ─▶ frontend (nginx)
   api.shortlink.local ─▶ api (podinfo) ─┬─▶ redis   (cache, Deployment)
                                         └─▶ postgres (StatefulSet + PVC)
```

Every layer is something you built this week: a Deployment, a Service, a ConfigMap + Secret, a StatefulSet with storage, probes + resources + an HPA, and an Ingress.

---

## Part 1 — Deploy the working stack (~30 min)

The files are numbered so a plain apply respects ordering:

```bash
kubectl apply -f shortlink/          # applies 00-namespace through 50-ingress in order
kubectl get all -n shortlink
```

Wait for everything Ready (`kubectl get pods -n shortlink -w`), then wire up hostnames — point both at `minikube ip` in your hosts file (see Day 8's OS notes):

```
192.168.49.2  shortlink.local api.shortlink.local
```

| Check | Command |
|---|---|
| Frontend loads | `curl -s http://shortlink.local` (or open it) |
| API responds | `curl -s http://api.shortlink.local` |
| API is talking to Redis | `kubectl logs -n shortlink deploy/api \| grep -i cache` |
| Postgres has its volume | `kubectl get pvc -n shortlink` |
| HPA is live | `kubectl get hpa -n shortlink` |

Take a minute in K9s: set the namespace with `:ns` → `shortlink`, then walk `:deploy`, `:sts`, `:svc`, `:ing`, `:hpa`. This is a real topology — appreciate that you can now read all of it.

---

## Part 2 — Lock it down with RBAC (~30 min)

Right now, anything with cluster access can read your Postgres password Secret. RBAC is what actually stops that (remember Day 4: base64 is not security — *permissions* are).

```bash
kubectl apply -f rbac/viewer-rbac.yaml     # a ServiceAccount that can ONLY read pods
```

Test the boundary with `kubectl auth can-i ... --as=<service account>`:

```bash
SA=system:serviceaccount:shortlink:viewer
kubectl auth can-i get   pods    --as=$SA -n shortlink     # yes
kubectl auth can-i list  pods    --as=$SA -n shortlink     # yes
kubectl auth can-i delete pods   --as=$SA -n shortlink     # no
kubectl auth can-i get   secrets --as=$SA -n shortlink     # no  ← the password is protected
```

That last `no` is the payoff: the `viewer` identity literally cannot read your Secret. **Least privilege** means every workload and human gets exactly the verbs/resources they need and nothing more.

| Piece | Job |
|---|---|
| **ServiceAccount** | the identity a pod (or person) acts as |
| **Role** | a set of allowed verbs on resources, in one namespace |
| **RoleBinding** | ties a ServiceAccount to a Role |

(A `ClusterRole` + `ClusterRoleBinding` do the same cluster-wide — that's your next step beyond this course.)

---

## Part 3 — The Gauntlet: fix eight bugs (~90 min) 🏁

This is the assessment. `shortlink-broken/` is the same app with **eight planted bugs — one from every day this week.** Your job: get it fully green, diagnosing each failure from the cluster's own signals.

**Rules of engagement**
- Diagnose from **K9s / `describe` / Events / logs / endpoints** — the way you would at work.
- Do **not** hunt through the YAML looking for the answer. Read the *symptom* first, form a hypothesis, *then* open the file to fix the specific line.
- Work in the `shortlink` namespace. (Tear down Part 1 first if it's still up: `kubectl delete namespace shortlink`, then recreate from the broken folder.)

```bash
kubectl apply -f shortlink-broken/
```

You'll hit an error on the very first apply — that's bug #1 of 8, and it's diagnosable. Keep going.

**A map of where the symptoms show up** (not the fixes — those you earn):

| Symptom you'll see | Which layer |
|---|---|
| `apply` prints a rejection error | a controller whose selector/template disagree |
| a pod stuck `ImagePullBackOff` | a bad image reference |
| a pod `CreateContainerConfigError` | config wiring |
| a pod `CrashLoopBackOff` (app is fine) | a health probe |
| `postgres-0` stuck `Pending` | storage |
| `shortlink.local` → 503 | a Service with no endpoints |
| `api.shortlink.local` → 503 (api is healthy) | ingress routing |
| the `reporter` pod's logs say `Forbidden` | RBAC |

**Done when:** both `shortlink.local` and `api.shortlink.local` respond, every pod in `-n shortlink` is Running/Ready, and `kubectl logs -n shortlink reporter` shows a clean pod list instead of a Forbidden error.

> **Instructors:** the complete answer key with every bug, file, and fix is in `shortlink-broken/BUGS.md`. Don't hand it out — use it to coach. Grade *how* students diagnosed (did they read Events and check endpoints?) over how fast they patched.

---

## Part 4 — What we did NOT cover (your map onward)

You can now deploy, expose, secure, and debug real workloads on Kubernetes. Here's what's deliberately beyond this course, so you know the shape of the next mountain:

- **Operators & CRDs** — teach Kubernetes new object types (e.g. a `PostgresCluster` kind) and the controller logic to manage them. How production databases actually run on K8s.
- **GitOps (Argo CD / Flux)** — stop running `kubectl apply` by hand; Git becomes the source of truth and a controller continuously reconciles the cluster to match it.
- **Service mesh (Istio / Linkerd)** — mTLS, traffic shifting, and per-request observability between services without changing app code.
- **Real multi-node clusters** — scheduling across nodes, affinity/anti-affinity, taints/tolerations, node pools — things minikube's single node hides.
- **Managed Kubernetes (EKS / GKE / AKS)** — cloud load balancers, IAM-integrated RBAC, autoscaling node groups, and who owns the control plane.
- **Advanced networking & policy** — `NetworkPolicy` (which we skipped) to firewall pod-to-pod traffic; CNI internals.

Each builds directly on what you did this week. You have the foundation now.

---

## Recap — the week in four questions

1. Trace a user request from `shortlink.local` all the way to a Postgres row. Name every Kubernetes object it passes through.
2. Your Secret holds a real password. Explain precisely what stops an arbitrary pod from reading it.
3. Pick any two of the eight bugs. For each: what was the symptom, and what was the *first* command you ran to localize it?
4. You inherit a cluster where "the app is down." Describe your first five minutes.

---

## Cleanup

```bash
kubectl delete namespace shortlink          # takes everything with it
minikube stop                               # or: minikube delete  (to reclaim all disk)
```

**That's the course.** You went from a single mortal Pod on Day 1 to deploying, securing, and debugging a full multi-service stack. Go build.
