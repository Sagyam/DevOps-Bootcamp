# Kubernetes Lab — 9-Day Blueprint

A day-wise, hands-on Kubernetes lab for the DevOps bootcamp. Built around **K9s as the cockpit** and **kubectl as the mirror**: every action is done in K9s first (so students *see* the cluster), then repeated as the equivalent kubectl command (so they can drive it headless later). Students **never author YAML or apps** — everything is provided. Their job is to **apply, observe, break, and fix**.

---

## Design decisions (read this first)

**The running app is a spine, not hello-worlds.** We use `stefanprodan/podinfo` as the primary workload across all 9 days. It's a purpose-built teaching microservice: it has `/healthz` and `/readyz` endpoints, a version-colored UI (so rolling updates are *visible*), a Prometheus `/metrics` endpoint, and failure-injection endpoints (`/panic`, `/delay/{s}`, `/status/{code}`, `/readyz/disable`) that let us break it on demand. Postgres and Redis join later for config/storage/stateful days, and a two-tier "real system" lands in the capstone.

**Continuity with the Docker module.** The Day 9 capstone re-deploys a slimmed **ShortLink**-style stack (api + postgres + redis + frontend) — the same app they containerized in the Docker module, now orchestrated. This closes the loop from "I built the image" to "I run it in a cluster."

**Every day has a "watch it break" moment.** Consistent with the teaching style used in the Docker (`builds but won't run`) and Linux (ufw lockout) modules, each day ends with a planted failure students diagnose live in K9s. Day 9 is a full break-fix gauntlet that doubles as the assessment.

**Every day has the same rhythm:**
1. **Mental model** (10–15 min whiteboard/slide) — the *why* before the *how*
2. **Guided lab** — instructor drives, students mirror (K9s action → kubectl equivalent)
3. **Provided manifests** — students apply and inspect
4. **Challenge** — students do it themselves, unguided
5. **Break-fix** — a planted failure to diagnose
6. **Recap + checks-for-understanding (CFU)**

**Timing.** Each day is a ~2–3 hour session. Days 1–6 are the conceptual core. Days 7–8 are tooling/exposure. Day 9 is synthesis. **If your calendar is tight, this compresses to 6–7 days** (merge 3+8 into one networking day, merge 5 into 4, and fold RBAC into the capstone). Notes on where to cut are at the end.

---

## Day 0 — Cluster bring-up (30 min, run at the top of Day 1)

Get everyone on an identical, healthy cluster before any teaching starts.

```bash
# Give the cluster enough headroom — the default 2GB will OOM us by Day 5
minikube start --cpus=4 --memory=6144 --driver=docker

# Addons we'll need over the week (enable now so we're not fighting them mid-lesson)
minikube addons enable metrics-server   # Day 6: kubectl top + HPA
minikube addons enable ingress          # Day 8: nginx ingress controller
minikube addons enable dashboard        # Day 8: optional GUI

# Sanity
kubectl cluster-info
kubectl get nodes -o wide
k9s   # should connect to the minikube context immediately
```

**Instructor note:** if a student's K9s opens on the wrong context, `:context` inside K9s (or `kubectl config use-context minikube`) fixes it. Verify everyone sees exactly one `Ready` node before proceeding.

---

## The K9s cockpit cheat-sheet (teach on Day 1, reuse all week)

Pin this somewhere students can see it every session. These are the keys we lean on:

| Key / command | Does |
|---|---|
| `:pods` `:deploy` `:svc` `:ns` `:cm` `:secret` `:pvc` `:sts` `:ing` `:hpa` `:events` `:helm` | Jump to a resource type |
| `/text` | Filter the current view |
| `d` | Describe (the single most-used key) |
| `l` | Logs · `p` toggles previous-container logs |
| `s` | Shell into the container |
| `y` | View the live YAML |
| `e` | Edit the resource in-place |
| `s` (on a deployment) | Scale replicas |
| `ctrl-d` | Delete |
| `<enter>` | Drill in (deploy → pods → containers) |
| `:xray deploy` | Tree view of a deployment and everything it owns |
| `:q` / `esc` | Back / quit |

The mental frame for students: **K9s is `kubectl get -w` + `describe` + `logs` + `exec` fused into one live dashboard.** Everything K9s does maps to a kubectl command — we'll always show both.

---

## Companion repo layout

All provided files live in one repo students clone. Structure:

```
k8s-lab/
├── README.md                      # this blueprint, student-facing
├── day-01-pods/
│   ├── README.md                  # objectives, steps, CFU
│   ├── pod.yaml
│   └── pod-broken.yaml            # break-fix: bad image
├── day-02-deployments/
│   ├── deployment.yaml
│   └── deployment-badtag.yaml
├── day-03-services/
│   ├── deployment.yaml
│   ├── service-clusterip.yaml
│   ├── service-nodeport.yaml
│   ├── client.yaml                # curl pod for DNS demos
│   └── service-bad-selector.yaml
├── day-04-config/
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── deployment-with-config.yaml
│   └── deployment-missing-key.yaml
├── day-05-storage/
│   ├── postgres-statefulset.yaml
│   ├── postgres-headless-svc.yaml
│   ├── pvc.yaml
│   └── pvc-pending.yaml           # wrong storageClass
├── day-06-health-resources/
│   ├── deployment-probes.yaml
│   ├── deployment-oom.yaml
│   ├── hpa.yaml
│   ├── loadgen.yaml
│   └── deployment-badprobe.yaml
├── day-07-helm/
│   ├── shortlink-chart/           # a real chart wrapping the stack
│   └── values-prod.yaml
├── day-08-ingress-observability/
│   ├── ingress.yaml
│   ├── whoami.yaml
│   ├── tls-secret.yaml
│   └── ingress-broken.yaml
└── day-09-capstone/
    ├── shortlink/                 # full working multi-tier app
    ├── shortlink-broken/          # 8 planted bugs, one per prior day
    └── rbac/
```

---

# Day 1 — The Cluster & the Pod

**Objective:** Build the mental model of a cluster (even a single-node one), get fluent in K9s + core kubectl, and understand what a Pod actually is — including why a bare Pod is *not* what you deploy in production.

### Mental model
- Control plane (API server, etcd, scheduler, controller-manager) vs kubelet/worker — draw it even though minikube collapses it onto one node. The key idea: **you talk to the API server; controllers reconcile desired state toward actual state.**
- **Declarative, not imperative.** You describe *what* you want (`kind: Pod`), the cluster figures out *how*. `kubectl apply` = "make reality match this file."
- A **Pod** = one or more co-located containers sharing network + storage. Smallest deployable unit. Usually one app container per pod.

### Guided lab
Provided `day-01-pods/pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: podinfo
  labels:
    app: podinfo
spec:
  containers:
    - name: podinfo
      image: stefanprodan/podinfo:6.7.0
      ports:
        - containerPort: 9898
```

| Action | K9s | kubectl |
|---|---|---|
| Apply the pod | — | `kubectl apply -f pod.yaml` |
| Watch it start | `:pods`, watch `Pending → ContainerCreating → Running` | `kubectl get pods -w` |
| Inspect it | `d` on the pod | `kubectl describe pod podinfo` |
| Read its logs | `l` | `kubectl logs podinfo` |
| Shell in | `s` | `kubectl exec -it podinfo -- sh` |
| Reach the app | `<shift-f>` port-forward → hit `localhost:9898` | `kubectl port-forward podinfo 9898:9898` |
| See raw state | `y` | `kubectl get pod podinfo -o yaml` |

Then the punchline: **delete the pod and watch it stay dead.**
```bash
kubectl delete pod podinfo   # in K9s: ctrl-d
# it does NOT come back — nobody is watching it. This is why we need Deployments.
```

### Concepts to surface
- Imperative escape hatches (`kubectl run`, `kubectl create`) vs declarative `apply` — we live in `apply`.
- `kubectl explain pod.spec.containers` — the built-in schema docs (students should reach for this instead of googling YAML fields).
- `kubectl api-resources` — everything the cluster knows about.
- Namespaces: `:ns` in K9s, `-n`, `--all-namespaces`. Show them `kube-system` so they see the cluster's own guts.

### Break-fix
`day-01-pods/pod-broken.yaml` has `image: stefanprodan/podinfo:6.7.0-typo`. Apply it → `ImagePullBackOff`. Students diagnose entirely from K9s: `d` on the pod, scroll to Events, read `Failed to pull image`. **Lesson: the Events section is where Kubernetes tells you what's wrong — always read it first.**

### CFU
- Why did the pod not restart when deleted?
- What's the difference between `kubectl create` and `kubectl apply`?
- Where do you look when a pod won't start?

---

# Day 2 — Deployments, ReplicaSets & Self-Healing

**Objective:** Understand the controller pattern (Deployment → ReplicaSet → Pods), self-healing, scaling, and — the star of the day — **rolling updates and rollbacks**, made visible by podinfo's version-colored UI.

### Mental model
- A **Deployment** manages a **ReplicaSet** which manages **Pods**. The RS's job: "keep N pods matching this label selector alive." Kill one → it makes another. This is the **reconciliation loop** in action.
- **Labels and selectors** are the glue. The RS finds its pods by selector, not by name.

### Guided lab
Provided `day-02-deployments/deployment.yaml` (3 replicas of podinfo). Apply it, then:

| Action | K9s | kubectl |
|---|---|---|
| See the ownership tree | `:xray deploy` (Deployment → RS → Pods) | `kubectl get deploy,rs,pods` |
| **Self-heal**: kill a pod | `ctrl-d` a pod, watch a replacement spawn instantly | `kubectl delete pod <name>` |
| Scale up/down | `s` on the deployment → set 5 | `kubectl scale deploy/podinfo --replicas=5` |
| **Rolling update** | `e` the deploy, bump image `6.7.0 → 6.7.1` | `kubectl set image deploy/podinfo podinfo=stefanprodan/podinfo:6.7.1` |
| Watch the rollout | pods view — old pods terminate as new appear | `kubectl rollout status deploy/podinfo` |
| Rollout history | — | `kubectl rollout history deploy/podinfo` |
| **Rollback** | — | `kubectl rollout undo deploy/podinfo` |

Port-forward to podinfo during the rollout — **the UI banner color/version changes as pods flip over.** This makes `maxSurge`/`maxUnavailable` tangible: only a couple pods are ever mid-swap.

### The killer labels demo
With `kubectl label pod <one-pod> app=orphan --overwrite`, you *remove* a running pod from the RS's selector. K9s instantly shows a **new** pod spawning (the RS thinks one went missing) while the orphan keeps running unmanaged. Nothing teaches "the selector is everything" faster than watching this.

### Break-fix
`deployment-badtag.yaml` rolls out to a nonexistent tag → new RS pods stuck `ImagePullBackOff`, **but the old pods keep serving** (rolling update is safe by default). Students diagnose the stuck rollout (`kubectl rollout status` hangs) and recover with `rollout undo`. **Lesson: a bad deploy doesn't take you down if you let the rollout gate on health.**

### CFU
- What are the three layers between `Deployment` and a running container?
- How does the ReplicaSet decide which pods are "its" pods?
- Your rollout is stuck. What do you check, and how do you get back to a working state?

---

# Day 3 — Services & Cluster Networking

**Objective:** Solve the "pod IPs are ephemeral" problem with Services, understand ClusterIP/NodePort/LoadBalancer, and — critically — learn to debug the #1 real-world networking bug: **a Service with no endpoints.**

### Mental model
- Pods are cattle; their IPs churn constantly. A **Service** is a stable virtual IP + DNS name that load-balances across whatever pods currently match its selector.
- **Endpoints** are the live list of pod IPs behind a service. When a pod goes unready, it's *pulled from endpoints*. This is the invisible machinery students must learn to see.
- **CoreDNS** gives every service a name: `podinfo.default.svc.cluster.local`.

### Guided lab
Provided: `deployment.yaml` (podinfo), `service-clusterip.yaml`, and `client.yaml` (a `curlimages/curl` pod that sleeps, for DNS demos).

```yaml
# service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo
spec:
  selector:
    app: podinfo
  ports:
    - port: 80
      targetPort: 9898
```

| Action | K9s | kubectl |
|---|---|---|
| See the service | `:svc` | `kubectl get svc` |
| **See its endpoints** | `:endpoints`, note the pod IPs | `kubectl get endpoints podinfo` |
| DNS discovery | `s` into the client pod → `curl http://podinfo` | `kubectl exec -it client -- curl podinfo` |
| Scale podinfo | `s` on deploy → watch endpoints list grow in real time | `kubectl scale deploy/podinfo --replicas=4` |
| NodePort | apply `service-nodeport.yaml` | `minikube service podinfo-np --url` |
| LoadBalancer | (needs `minikube tunnel` in a second terminal) | `kubectl get svc -w` for the external IP |

**The endpoints-track-readiness demo:** scale down to 1 and watch the endpoints list shrink live in K9s. This is the visual that makes "services route to *ready* pods only" click — and sets up probes on Day 6.

### Service types, briefly
- **ClusterIP** — internal only (default; 90% of services).
- **NodePort** — opens a port on the node; how you reach things in minikube without extras.
- **LoadBalancer** — asks the cloud for an LB; in minikube, `minikube tunnel` fakes one.

### Break-fix
`service-bad-selector.yaml` targets `app: podinfoo` (typo). Applies cleanly, but `curl podinfo` **times out**. Students discover via K9s that `:endpoints` shows **`<none>`** — no pods match. **Lesson: "connection refused / timeout" + empty endpoints = selector mismatch. This is the most common Kubernetes bug in the wild, and it never produces an error on apply.**

### CFU
- Why can't you just talk to a pod by its IP?
- A teammate says "the service is up but nothing connects." What's the first thing you check?
- What removes a pod from a service's rotation without deleting it?

---

# Day 4 — Configuration: ConfigMaps & Secrets

**Objective:** Separate config from image (twelve-factor), wire ConfigMaps and Secrets into workloads via env vars and volume mounts, and be honest about what Secrets do and don't protect.

### Mental model
- Bake config into the image → you rebuild for every environment. Externalize it → one image, many configs. **ConfigMap** = non-secret key/values; **Secret** = same shape, base64-encoded, treated specially by RBAC and mounts.
- Two injection styles: **env vars** (`env`, `envFrom`) and **mounted files** (a volume). Key subtlety: **mounted config updates propagate to the pod; env vars do not** (they're fixed at container start).

### Guided lab
Provided `configmap.yaml`, `secret.yaml`, and `deployment-with-config.yaml` (podinfo reading `PODINFO_UI_COLOR`, `PODINFO_UI_MESSAGE` from the ConfigMap and a fake `API_TOKEN` from the Secret).

| Action | K9s | kubectl |
|---|---|---|
| Create from literals | — | `kubectl create configmap app-config --from-literal=ui.color='#34577c'` |
| View config | `:cm` → `y` | `kubectl get cm app-config -o yaml` |
| **Decode a secret** | `:secret` → `x` (K9s decodes it inline) | `kubectl get secret app-secret -o jsonpath='{.data.token}' \| base64 -d` |
| See it injected | `s` into pod → `env \| grep PODINFO` | `kubectl exec deploy/podinfo -- env` |
| Edit + observe | `e` the configmap, change the message | (mounted config updates; env-injected does not until restart) |

Port-forward to podinfo — the UI message/color reflects the ConfigMap. Change it and discuss *why* an env-based value needs a pod restart (`kubectl rollout restart deploy/podinfo`) while a mounted one eventually refreshes.

### The honesty slide
**Base64 is encoding, not encryption.** Anyone with `get secret` rights reads it instantly (as K9s just demonstrated with `x`). Real protection comes from RBAC (Day 9), encryption-at-rest, and external secret stores. Don't let students leave thinking Secrets are "secure by default."

### Break-fix
`deployment-missing-key.yaml` references a ConfigMap key that doesn't exist. Pod is stuck in `CreateContainerConfigError`. Students `d` the pod, read the event `couldn't find key ... in ConfigMap`. **Lesson: config errors fail the container *before* your app code ever runs — and the pod never reaches Running.**

### CFU
- When would you mount config as a file vs inject it as an env var?
- Why did your env-var change not take effect until you restarted the pod?
- Is a Kubernetes Secret encrypted? Who can read it?

---

# Day 5 — Storage & Stateful Workloads

**Objective:** Understand ephemeral vs persistent storage, the PV/PVC/StorageClass model with dynamic provisioning, and why databases need **StatefulSets** (stable identity + storage) rather than Deployments.

### Mental model
- A pod's container filesystem is **ephemeral** — restart and it's gone. `emptyDir` survives container restarts but not pod deletion.
- **PersistentVolume (PV)** = a real disk. **PersistentVolumeClaim (PVC)** = a request for one. **StorageClass** = the template that dynamically provisions a PV to satisfy a claim. minikube ships a default `standard` StorageClass, so claims bind automatically.
- **StatefulSet** vs Deployment: stable network identity (`postgres-0`, `postgres-1`), stable per-pod storage, ordered rollout. This is what databases need.

### Guided lab
Provided `postgres-statefulset.yaml`, `postgres-headless-svc.yaml`, `pvc.yaml`.

| Action | K9s | kubectl |
|---|---|---|
| Watch dynamic provisioning | `:pvc` → `Pending → Bound`, then `:pv` shows the auto-created volume | `kubectl get pvc,pv -w` |
| See the StorageClass | `:sc` | `kubectl get storageclass` |
| StatefulSet ordering | `:sts` then pods — note `postgres-0` appears before `postgres-1` | `kubectl get pods -w` |
| **Prove persistence** | shell into `postgres-0`, `psql`, write a row; delete the pod; it returns as `postgres-0` with the **same PVC** — row survives | `kubectl delete pod postgres-0` |
| Prove destruction | delete the **PVC** → data is gone | `kubectl delete pvc <name>` |

The persistence demo (write data → kill pod → data survives; delete PVC → data gone) is the whole lesson in one sequence. Students should feel the difference between "pod died" and "storage died."

### Break-fix
`pvc-pending.yaml` requests `storageClassName: fast-ssd` (doesn't exist). PVC hangs in `Pending` forever; the pod that mounts it hangs in `Pending` too. Students `d` the PVC → event `storageclass.storage.k8s.io "fast-ssd" not found`. **Lesson: a pod stuck Pending is often a storage or scheduling problem, not an app problem — describe the PVC, not just the pod.**

### CFU
- What's the difference between deleting a StatefulSet pod and deleting its PVC?
- Why can't you just use a Deployment for Postgres?
- Your pod is Pending and never starts. Name two non-app causes.

---

# Day 6 — Health, Resources & Scheduling

**Objective:** The heaviest day. Make workloads production-real with **probes**, **resource requests/limits**, and **autoscaling** — and generate the classic failures (`CrashLoopBackOff`, `OOMKilled`, `Unschedulable`) on purpose so students recognize them forever. This is your "builds but won't run" day for Kubernetes.

### Mental model
- **Liveness probe** — "is it wedged? restart it." **Readiness probe** — "is it ready for traffic? if not, pull it from the service." **Startup probe** — "give slow starters time before liveness kicks in." Confusing liveness with readiness causes real outages.
- **Requests** = what the scheduler reserves. **Limits** = the hard ceiling. Exceed a memory limit → **OOMKilled**. Exceed a CPU limit → throttled (not killed). Requests too high → pod can't be scheduled.
- **QoS classes** (Guaranteed / Burstable / BestEffort) decide who gets evicted first under pressure.

### Guided lab
Provided `deployment-probes.yaml` (podinfo with liveness/readiness on `/healthz` and `/readyz`, plus requests/limits):
```yaml
        livenessProbe:
          httpGet: { path: /healthz, port: 9898 }
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet: { path: /readyz, port: 9898 }
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests: { cpu: 100m, memory: 64Mi }
          limits:   { cpu: 500m, memory: 128Mi }
```

| Action | K9s | kubectl |
|---|---|---|
| **Toggle readiness live** | port-forward, `curl -X POST podinfo:9898/readyz/disable` → watch the pod drop from `:endpoints` and go `0/1 Ready` | — |
| **Force a liveness restart** | `curl -X POST podinfo:9898/panic` → watch `RESTARTS` climb in K9s | `kubectl get pods -w` |
| See resource usage | `:pods` shows CPU/MEM columns | `kubectl top pods` (needs metrics-server) |
| Autoscale | apply `hpa.yaml` (target 50% CPU) | `kubectl get hpa -w` |
| Generate load | apply `loadgen.yaml` (a busybox wget loop) → watch HPA scale replicas up in `:hpa` and `:deploy` | — |

The readiness-toggle demo ties directly back to Day 3: students *see* the pod leave the service's endpoint list the instant it goes unready, then rejoin when re-enabled.

### Scheduling (lighter on single-node, but conceptually essential)
- **Requests too high**: `deployment-oom.yaml` variant requesting `cpu: 8` → pod stuck `Pending`, `d` shows `0/1 nodes available: Insufficient cpu`.
- **Taints/tolerations**: `kubectl taint node minikube demo=true:NoSchedule` → new pods go Pending until you add a matching toleration. Untaint after: `kubectl taint node minikube demo=true:NoSchedule-`.

### Break-fix (two flavors)
1. **`deployment-badprobe.yaml`** — liveness probe points at the wrong path (`/health` instead of `/healthz`). The app is perfectly healthy, but the probe fails, so Kubernetes **kills it every 30s → `CrashLoopBackOff`**. Students must realize the *app* is fine and the *probe* is the bug (`d` → events show probe failures). This is one of the most common and most confusing real-world failures.
2. **`deployment-oom.yaml`** — memory limit set absurdly low (`memory: 8Mi`) → `OOMKilled`, restart loop. `d` shows `Last State: Terminated, Reason: OOMKilled`.

### CFU
- A pod restarts every 30 seconds but the app logs look fine. What's your prime suspect?
- Difference between a failed liveness probe and a failed readiness probe — what does each *do*?
- OOMKilled vs Pending-due-to-insufficient-memory: which is a limit problem and which is a request problem?

---

# Day 7 — Helm: Packaging & Releasing

**Objective:** Now that they've hand-applied ~20 manifests, motivate Helm as templated, versioned, releasable packaging. Install a public chart, then a custom one, and use upgrade/rollback.

### Mental model
- Raw `kubectl apply` = loose files, no versioning, copy-paste per environment. **Helm** = a **chart** (templated manifests) + **values** (the knobs) → a **release** (an installed, versioned instance you can upgrade and roll back).
- `helm template` renders the chart to plain YAML — the debugging superpower.

### Guided lab

**Public chart first** (instant payoff):
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm install demo podinfo/podinfo
helm list
```

| Action | K9s | helm/kubectl |
|---|---|---|
| **See releases in K9s** | `:helm` — K9s lists Helm releases natively | `helm list` |
| Inspect what it created | `:deploy`, `:svc` filtered to the release | `helm get manifest demo` |
| Override a value | — | `helm upgrade demo podinfo/podinfo --set replicaCount=3` |
| Rollback | — | `helm rollback demo 1` |
| History | — | `helm history demo` |
| Uninstall | `ctrl-d` on the release in `:helm` | `helm uninstall demo` |

**Custom chart** (`day-07-helm/shortlink-chart/`): a provided chart wrapping the api+redis stack. Show `values.yaml` as the single source of knobs, then:
```bash
helm template ./shortlink-chart -f values-prod.yaml   # render, don't apply — read the output
helm install shortlink ./shortlink-chart -f values-prod.yaml
```
Walk the template syntax lightly: `{{ .Values.image.tag }}`, an `if`, a `range`, and `_helpers.tpl` for the name template. They're *reading* templates, not writing them — but they should recognize the shapes.

### Break-fix
`helm upgrade` with a broken value (`replicaCount: -1` or a bad image tag) → failed release. Students recover with `helm rollback` and learn to pre-flight with `helm template` / `helm lint` **before** upgrading. **Lesson: `helm template` renders locally with zero cluster risk — always render before you upgrade.**

### CFU
- What problem does Helm solve that plain `kubectl apply` doesn't?
- How do you see what a chart *would* create without touching the cluster?
- Your upgrade broke prod. What's the one command that saves you?

---

# Day 8 — Ingress & Observability

**Objective:** Expose services to the outside world with Ingress (host/path routing, TLS), and build the habit of *reading the cluster's story* through events, logs, and metrics.

### Mental model
- A Service gets you *to* a pod; an **Ingress** gives you HTTP routing (hostnames, paths, TLS termination) in front of many services, handled by an **ingress controller** (the nginx one we enabled Day 0).
- Observability isn't a tool — it's a habit: **events → logs → metrics → describe**, in that order, reading the chain from symptom to cause.

### Guided lab
Provided `ingress.yaml` (routes `podinfo.local` → podinfo, `whoami.local` → whoami), `whoami.yaml`, `tls-secret.yaml` (self-signed).

```bash
# minikube's ingress addon serves on the minikube IP
minikube ip                     # e.g. 192.168.49.2
# add to /etc/hosts:  192.168.49.2  podinfo.local whoami.local
curl http://podinfo.local
curl http://whoami.local
```

| Action | K9s | kubectl |
|---|---|---|
| See ingress rules | `:ing` → `d` for the routing table | `kubectl describe ingress web` |
| Watch the controller | `:pods -n ingress-nginx` | `kubectl get pods -n ingress-nginx` |
| **Cluster-wide events** | `:events` (sorted, live) | `kubectl get events --sort-by=.lastTimestamp` |
| Previous-crash logs | `l` then `p` | `kubectl logs <pod> --previous` |
| Live metrics | `:pods` CPU/MEM columns | `kubectl top nodes` / `kubectl top pods` |
| GUI overview | — | `minikube dashboard` |

### Break-fix
`ingress-broken.yaml` routes to a service name/port that doesn't exist → **502/404**. Students trace the whole chain: `Ingress → Service → Endpoints → Pod`, discovering the break is a wrong `service.port`. **Lesson: an ingress failure is almost never the ingress — walk the chain down to endpoints (echoes Day 3).**

### CFU
- Service vs Ingress — when do you need each?
- You get a 502 through the ingress. Walk me down the chain you'd check.
- Where do you find logs from a container that already crashed and restarted?

---

# Day 9 — Capstone: Real System + Break-Fix Gauntlet + RBAC

**Objective:** Synthesize everything by deploying a real multi-tier app, get a first taste of RBAC, then prove mastery through a **timed break-fix gauntlet** that doubles as the assessment.

### Part 1 — Deploy the ShortLink stack (guided, ~45 min)
Provided `day-09-capstone/shortlink/`: a working multi-tier app in a dedicated `shortlink` namespace — **frontend (nginx) + api (podinfo standing in for the URL service) + postgres (StatefulSet + PVC) + redis (Deployment)**, wired with ConfigMaps/Secrets, probes, requests/limits, an HPA, and an Ingress. Every concept from Days 1–8 appears exactly once. Students deploy it and verify end-to-end through the ingress. This is the "it all fits together" moment — and the callback to the Docker module's ShortLink.

### Part 2 — RBAC intro (~30 min)
Provided `rbac/`: a restricted ServiceAccount with a Role that can only `get`/`list` pods in the `shortlink` namespace.
```bash
kubectl auth can-i delete pods --as=system:serviceaccount:shortlink:viewer -n shortlink   # no
kubectl auth can-i get pods    --as=system:serviceaccount:shortlink:viewer -n shortlink   # yes
```
Ties back to Day 4's honesty slide: *this* is what actually protects your Secrets. Keep it conceptual — ServiceAccount → Role → RoleBinding, and `auth can-i` as the tool.

### Part 3 — The Break-Fix Gauntlet (the assessment, ~60 min)
Provided `shortlink-broken/`: the same stack with **8 planted bugs, one drawn from each prior day.** Students race to get the app green using K9s + kubectl only:

| # | Planted bug | Day it tests | Symptom |
|---|---|---|---|
| 1 | Typo'd image tag | 1 | ImagePullBackOff |
| 2 | Deployment selector ≠ pod labels | 2 | 0 pods ever appear |
| 3 | Service selector mismatch | 3 | empty endpoints, frontend can't reach api |
| 4 | Missing ConfigMap key | 4 | CreateContainerConfigError |
| 5 | PVC wrong storageClass | 5 | postgres stuck Pending |
| 6 | Liveness probe wrong path | 6 | api CrashLoopBackOff |
| 7 | Ingress wrong service port | 8 | 502 through ingress |
| 8 | RBAC too restrictive for a sidecar | 9 | Forbidden in logs |

Grade on how many they fix and — more importantly — whether they diagnosed via **describe/events** rather than guessing. This is a direct extension of the failure-driven style from the earlier modules.

### Wrap-up: what we didn't cover (the bridge forward)
Be explicit about the map's edges so they know what's next: **Operators & CRDs, GitOps (ArgoCD/Flux), service mesh (Istio/Linkerd), multi-node & real cloud clusters (EKS/GKE/AKS), network policies, and production security.** Hand out a one-page kubectl + K9s cheat-sheet as the takeaway.

---

## Compressing to 6–7 days

If the calendar won't fit 9:
- **Merge Day 3 + Day 8** into one "Networking: Services → Ingress" day (drop the deep DNS/LoadBalancer detour).
- **Fold Day 5** into Day 4 as "Config & Storage" (keep the StatefulSet persistence demo, cut the taints/affinity tangent).
- **Move RBAC** entirely into the Day 9 capstone (already there).
- That yields: Pods → Deployments → Networking → Config+Storage → Health/Resources → Helm → Capstone = **7 days.** Cut Helm to a half-day and you're at 6.

Do **not** cut the break-fix segments to save time — they're where the learning actually sticks. Cut breadth (LoadBalancer, affinity, TLS) before you cut the failures.
