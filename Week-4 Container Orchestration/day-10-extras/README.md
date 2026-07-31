# Jobs, Namespaces & Quotas, CRDs, and Operators

**A hands-on lab for minikube + k9s**

Everything up to now has been about workloads that are supposed to run *forever* — Deployments,
Services, ReplicaSets. Today you learn the other half of Kubernetes:

1. **Jobs & CronJobs** — workloads that are supposed to *stop*.
2. **Namespaces, ResourceQuota, LimitRange** — how you stop one team from eating the whole cluster.
3. **CustomResourceDefinitions** — how you teach the Kubernetes API server a brand new noun.
4. **Operators** — what happens when someone writes a controller for that new noun, and how you
   configure one through `values.yaml`.

These four are in this order for a reason. Part 4 only makes sense once you have built the
tiny broken version of it yourself in Part 3.

**Time:** roughly 4–5 hours including breaks.

---

## 0. Before you start

### What you need installed

| Tool | Check with | Minimum |
|---|---|---|
| minikube | `minikube version` | 1.33 |
| kubectl | `kubectl version --client` | 1.28 (we use `--subresource`, needs ≥ 1.24) |
| helm | `helm version` | 3.12 |
| k9s | `k9s version` | 0.32 |

### Start the cluster

We need more room than usual — an operator or two is heavier than the apps you have been
deploying so far.

```bash
bash 00-setup/minikube-start.sh
```

That script is short, open it. It starts a profile called `jobs-lab` with 4 CPUs and 8 GB, and
turns on the `metrics-server` addon so that `kubectl top` and the CPU/MEM columns in k9s work.

Verify:

```bash
kubectl config current-context     # -> jobs-lab
kubectl get nodes
kubectl top nodes                  # may take ~60s after start before it answers
```

> **Low on RAM?** 4 CPU / 6 GB is survivable if you skip `kube-prometheus-stack` in Part 4
> (it is by far the heaviest thing we install). Do not go below 4 GB.

### Files you were given

```
.
├── 00-setup/minikube-start.sh
├── 01-jobs/            # Part 1
├── 02-namespaces/      # Part 2
├── 03-crd/             # Part 3
├── 04-operators/       # Part 4
└── 99-cleanup/cleanup.sh
```

**Every YAML file in this repo has comments in it.** Read the file before you apply it. If you
only run the commands in this README you will finish the lab without learning anything.

---

Two commands worth knowing today:

```
:crd            # every custom resource type in the cluster; press Enter on one to list its objects
:events         # cluster events, sorted -- your first stop when something silently does nothing
```

---

## Part 1 — Jobs and CronJobs

**Concept.** A Deployment says "always keep N Pods running". A **Job** says "run Pods until N of
them have *exited successfully*, then stop". A **CronJob** says "create a Job on this schedule".

```
Deployment -> ReplicaSet -> Pod   (restart forever)
CronJob    -> Job        -> Pod   (run to completion)
```

Create the namespace we will work in:

```bash
kubectl apply -f 01-jobs/00-namespace.yaml
```

In k9s, press `:ns`, then Enter on `jobs-lab` to scope your view to it.

### 2.1 A Job that succeeds

```bash
kubectl apply -f 01-jobs/01-hello-job.yaml
kubectl get jobs -n jobs-lab -w        # Ctrl-C when COMPLETIONS shows 1/1
kubectl logs -n jobs-lab job/hello-chiya
```

**Notice:**

- The Pod's status ends at `Completed`, not `Running`. It is *not* restarted. This is the whole
  point of a Job.
- `kubectl logs job/<name>` works — it resolves to the Job's Pod for you.
- Delete the Job and the Pod disappears with it (`ownerReferences` — check with
  `kubectl get pod -n jobs-lab <pod> -o yaml | grep -A5 ownerReferences`).

**Break it on purpose.** Edit `01-hello-job.yaml`, remove the `restartPolicy: Never` line and
re-apply. Read the error. Now you will recognise it forever:

```
The Job "hello-chiya" is invalid: spec.template.spec.restartPolicy:
Unsupported value: "Always": supported values: "OnFailure", "Never"
```

### 2.2 Parallelism

```bash
kubectl apply -f 01-jobs/02-parallel-job.yaml
```

Watch it in k9s (`:pods`). Six cups of chiya, two stoves:

- `completions: 6` — how many Pods must succeed in total.
- `parallelism: 2` — how many may run at once.

**Notice:** two Pods at a time, six `Completed` Pods at the end, and then — after
`ttlSecondsAfterFinished: 120` — the whole Job vanishes on its own. Without that field, finished
Jobs accumulate in a cluster for months. Go and look at any real cluster; you will find Jobs from
last year.

### 2.3 Indexed Jobs

```bash
kubectl apply -f 01-jobs/03-indexed-job.yaml
kubectl get pods -n jobs-lab -l job-name=shard-report
```

**Notice:** Pod names end `-0` through `-4`, and each container sees a different
`JOB_COMPLETION_INDEX`. This is how you shard work — "reprocess partition 3 of 5" — without
needing a queue.

```bash
for i in 0 1 2 3 4; do kubectl logs -n jobs-lab shard-report-$i-* 2>/dev/null; done
```

### 2.4 A Job that fails

```bash
kubectl apply -f 01-jobs/04-failing-job.yaml
kubectl get pods -n jobs-lab -l job-name=burnt-chiya -w
```

**Notice:**

- With `restartPolicy: Never`, each retry is a **brand new Pod**. You get 4 of them:
  1 attempt + `backoffLimit: 3` retries.
- The gaps between retries grow: 10s, 20s, 40s… (capped at 6 min). That is the exponential backoff.
- After the last failure: `kubectl describe job -n jobs-lab burnt-chiya` shows
  `BackoffLimitExceeded`.

Now change `restartPolicy` to `OnFailure`, delete and re-apply the Job, and watch again. This time
the **same Pod** restarts and its `RESTARTS` counter climbs. Both behaviours are useful; know which
one you are getting, because with `Never` your failed Pods stay around for debugging, and with
`OnFailure` the evidence is overwritten (use `kubectl logs --previous`).

### 2.5 Deadlines

```bash
kubectl apply -f 01-jobs/05-deadline-job.yaml
kubectl get job -n jobs-lab slow-kettle -w
```

After 20 seconds: `DeadlineExceeded`. `activeDeadlineSeconds` is a hard wall-clock limit on the
whole Job and it **overrides** `backoffLimit` — no more retries once the clock runs out. Every
production CronJob should have one, otherwise a hung run blocks the next one forever.

### 2.6 The real one: a database migration

This is the pattern you will actually write at work.

```bash
kubectl apply -f 01-jobs/07-migration-job.yaml     # apply the Job FIRST
kubectl get pods -n jobs-lab
```

The Pod sits in `Init:0/1`. Look at the init container's logs — it is waiting for a database that
does not exist yet:

```bash
kubectl logs -n jobs-lab -l job-name=db-migration -c wait-for-db --tail=5
```

Now give it a database:

```bash
kubectl apply -f 01-jobs/06-chiya-db.yaml
kubectl logs -n jobs-lab -l job-name=db-migration -c migrate -f
```

**Notice the shape:** an init container blocks until the dependency is ready, then the main
container does the work exactly once. That structure — not the SQL — is what you are learning.

**Discuss:** this Job's SQL is `CREATE TABLE IF NOT EXISTS` (safe to re-run) but the `INSERT` is
not. If the Job retries after a partial failure you get duplicate rows. Migration Jobs must be
**idempotent**, because Kubernetes *will* retry them. This bites people in production.

### 2.7 CronJob

```bash
kubectl apply -f 01-jobs/08-cronjob-report.yaml
kubectl get cronjob -n jobs-lab
```

Wait for the top of the next minute. In k9s: `:cj`, then Enter on `hourly-sales-report` to drill
into the Jobs it creates, then Enter again for the Pods.

```bash
kubectl get jobs -n jobs-lab            # a new Job appears every minute
kubectl logs -n jobs-lab job/hourly-sales-report-<something>
```

Things to try:

```bash
# pause without deleting -- your on-call superpower
kubectl patch cronjob -n jobs-lab hourly-sales-report -p '{"spec":{"suspend":true}}'

# fire one right now, without waiting for the schedule
kubectl create job -n jobs-lab manual-run --from=cronjob/hourly-sales-report
```

In k9s you can do that second one by selecting the CronJob and pressing `t`.

**Notice:** `successfulJobsHistoryLimit: 3` means old Jobs are garbage-collected. And
`concurrencyPolicy: Forbid` means if a run overruns into the next scheduled slot, the new run is
skipped rather than piling up. The three options:

| Policy | Behaviour when the previous run is still going |
|---|---|
| `Allow` (default) | start anyway — two runs in parallel |
| `Forbid` | skip this run |
| `Replace` | kill the old run, start the new one |

### Checkpoint 1

You can answer these without looking:

- Why does a Job reject `restartPolicy: Always`?
- What is the difference between `completions` and `parallelism`?
- Which field guarantees a Job cannot run forever?
- What is the object chain from a CronJob to a container?
- Why do finished Jobs pile up, and which field fixes it?

Clean up Part 1 (keep the namespace, we'll delete it at the end):

```bash
kubectl delete job -n jobs-lab --all
```

---

## 3. Part 2 — Namespaces, ResourceQuota, LimitRange

**Concept.** A Namespace is a name-scoping boundary, not a security boundary and not a machine.
Pods in `chiya-dev` and `chiya-prod` can still run on the same node and — unless you add
NetworkPolicies — still talk to each other. What a Namespace *does* give you is a place to hang
policy: quotas, limits, RBAC, Pod Security admission.

```bash
kubectl apply -f 02-namespaces/01-namespaces.yaml
kubectl get ns --show-labels
```

### 3.1 The budget: ResourceQuota

```bash
kubectl apply -f 02-namespaces/02-quota-compute.yaml
kubectl apply -f 02-namespaces/03-quota-objects.yaml
kubectl describe quota -n chiya-dev
```

You should see a `Used / Hard` table. In k9s: `:quota`.

### 3.2 The trap

Deploy an app that declares no CPU/memory at all:

```bash
kubectl apply -f 02-namespaces/05-app-no-resources.yaml
kubectl get deploy,rs,pods -n chiya-dev
```

**The Deployment exists. The ReplicaSet exists. There are zero Pods.** No error was printed by
`kubectl apply`. This is one of the most confusing failures in Kubernetes, and today is the day it
stops confusing you.

Where the error actually lives:

```bash
kubectl describe rs -n chiya-dev -l app=chiya-api | tail -20
```

```
Error creating: pods "chiya-api-..." is forbidden: failed quota: compute-quota:
must specify limits.cpu for: podinfo; limits.memory for: podinfo; ...
```

**The rule:** once a namespace has a compute ResourceQuota, every Pod must declare the constrained
fields. The Deployment controller happily creates the ReplicaSet; the ReplicaSet controller is the
one that gets rejected, and it reports it in *its* events, not the Deployment's.

> **Debugging ladder for "my Deployment made no Pods":**
> `describe deployment` → `describe replicaset` → `get events`. The error is almost always one
> level below where you looked first.

### 3.3 The fix: LimitRange

```bash
kubectl apply -f 02-namespaces/04-limitrange.yaml
kubectl rollout restart deploy -n chiya-dev chiya-api
kubectl get pods -n chiya-dev
```

Pods now start. Look at what you never typed:

```bash
kubectl get pod -n chiya-dev -l app=chiya-api -o jsonpath='{.items[0].spec.containers[0].resources}' | python3 -m json.tool
```

The LimitRange injected `requests: 100m/128Mi` and `limits: 200m/256Mi` at admission time.

**The distinction to memorise:**

| | Scope | Answers |
|---|---|---|
| **ResourceQuota** | the whole namespace | "this team may use at most 1 CPU in total" |
| **LimitRange** | one container / one PVC | "no single container may ask for more than 1 CPU, and if it asks for nothing, give it 100m" |

They are usually deployed as a pair. A quota without a LimitRange makes developers angry; a
LimitRange without a quota does not actually cap anything.

### 3.4 Getting rejected two different ways

```bash
kubectl apply -f 02-namespaces/06-app-too-big.yaml
kubectl describe rs -n chiya-dev -l app=chiya-greedy | tail -15
```

Read carefully — which rule fired first, the LimitRange `max` or the quota's `requests.cpu`?
(Hint: LimitRange is a *validating* admission check on the Pod itself; the quota check needs to add
up the namespace. Both are in the message.)

### 3.5 A well-behaved app

```bash
kubectl apply -f 02-namespaces/07-app-right-size.yaml
kubectl describe quota compute-quota -n chiya-dev
```

Now the `Used` column moves. Try scaling until you hit the wall:

```bash
kubectl scale deploy -n chiya-dev chiya-web --replicas=10
kubectl get deploy -n chiya-dev chiya-web        # never reaches 10/10
kubectl describe rs -n chiya-dev -l app=chiya-web | grep -i forbidden
```

**Notice:** the quota does not kill running Pods. It refuses *new* ones. Scale back down to 2:

```bash
kubectl scale deploy -n chiya-dev chiya-web --replicas=2
```

### 3.6 Object-count quotas

```bash
kubectl create deployment nginx1 --image=nginx -n chiya-dev
kubectl create deployment nginx2 --image=nginx -n chiya-dev   # count/deployments.apps: 3 -> rejected
```

This is the guardrail that saves you when a CI pipeline goes into a loop.

### Checkpoint 2

- Is a Namespace a security boundary? What would you add to make it closer to one?
- Your Deployment created no Pods and printed no error. What are your next three commands?
- Which object gives defaults, and which gives a ceiling?
- Does a ResourceQuota evict Pods that are already running?

---

## 4. Part 3 — CustomResourceDefinitions

**Concept.** The Kubernetes API server is a generic, schema-driven object store with
authentication, authorisation, validation, versioning and watch built in. A **CRD** registers a new
kind of object in it. After you apply one, your new kind behaves *exactly* like a built-in:
`kubectl get`, labels, RBAC, `kubectl explain`, k9s views — all free.

A CRD gives you **storage and validation**. It gives you **no behaviour**. Nothing happens when you
create the object. Behaviour is a separate program: a **controller**. We will write one.

### 4.1 Register the type

```bash
kubectl apply -f 03-crd/01-chiya-crd.yaml
kubectl get crd chiyas.chiyashop.dev
kubectl api-resources | grep chiya
```

Read `01-chiya-crd.yaml` now, top to bottom. The parts that matter:

| Field | Why you care |
|---|---|
| `metadata.name` | must be exactly `<plural>.<group>` — the API server rejects anything else |
| `scope` | `Namespaced` (like a Pod) or `Cluster` (like a StorageClass) |
| `names.shortNames`, `categories` | `kubectl get chy`, `kubectl get chiyashop` |
| `versions[].served` / `storage` | you may serve many versions; exactly one is stored in etcd |
| `subresources.status` | separates *desired* (spec, written by users) from *observed* (status, written by controllers) |
| `additionalPrinterColumns` | the columns in `kubectl get` and in k9s |
| `schema.openAPIV3Schema` | validation, defaults, **and** `kubectl explain` documentation |
| `x-kubernetes-validations` | CEL expressions for cross-field rules OpenAPI cannot express |

The API server is now serving a new endpoint. Look at it directly:

```bash
kubectl explain chiyas.spec
kubectl explain chiyas.spec.strength
kubectl get --raw /apis/chiyashop.dev/v1alpha1 | python3 -m json.tool
```

`kubectl explain` works because you wrote `description:` fields in the schema. Your CRD documents
itself.

### 4.2 Create some custom resources

```bash
kubectl apply -f 03-crd/02-chiya-samples.yaml
kubectl get chiyas -n chiya-dev
kubectl get chy -n chiya-dev -o wide
```

Your printer columns show up. In k9s: press `:` and type `chiyas` (or `:crd` and press Enter on
`chiyas.chiyashop.dev`).

**Notice the defaults.** You never wrote `sugarSpoons` for `morning-masala`:

```bash
kubectl get chiya -n chiya-dev morning-masala -o yaml | head -30
```

The API server filled in `sugarSpoons: 2`, `milk: true` from the schema. Defaulting happens
server-side at write time, so every client sees the same object.

### 4.3 Watch validation reject you

```bash
kubectl apply -f 03-crd/03-chiya-invalid.yaml
```

Four objects, four different validation mechanisms, four different error messages. Map each error
to the line in the CRD that produced it. This is the exercise — do not skip it.

### 4.4 The pruning gotcha

```bash
kubectl apply -f 03-crd/04-chiya-pruning.yaml
kubectl get chiya -n chiya-dev spiced -o yaml
```

Where did `cardamom` and `ginger` go? **Accepted, then silently deleted.** Structural schemas prune
any field they do not know about. No warning, no error. When someone says "Kubernetes ate my CR
field", this is why — a typo in a field name is indistinguishable from an unknown field.

Try the typo version:

```bash
kubectl apply -f 03-crd/04-chiya-pruning.yaml --validate=strict
```

`--validate=strict` (client-side, default in recent kubectl for known fields) or
`--dry-run=server` will surface unknown fields as warnings. Teach your team to use it.

### 4.5 Quotas on custom resources

Part 2 and Part 3 meet:

```bash
kubectl delete chiya -n chiya-dev spiced          # back down to 3
kubectl apply -f 03-crd/07-chiya-quota.yaml
kubectl describe quota chiya-cr-quota -n chiya-dev

# now try to create a 4th
kubectl apply -f 03-crd/04-chiya-pruning.yaml     # forbidden: exceeded quota
```

`count/<plural>.<group>` works for *any* resource, including ones that did not exist when
Kubernetes was written. That is how far the extension model goes.

### 4.6 Write a controller (this is the important bit)

Right now your `Chiya` objects are inert rows in etcd. `status` is empty because nothing has ever
looked at them. Let us fix that.

```bash
kubectl apply -f 03-crd/05-controller-rbac.yaml
kubectl apply -f 03-crd/06-controller.yaml
kubectl logs -n chiya-system deploy/chiya-controller -f
```

Now, in another terminal:

```bash
kubectl get chiyas -n chiya-dev            # PHASE column fills in
kubectl get configmaps -n chiya-dev        # recipe-<name> appeared for each Chiya
```

**Read `06-controller.yaml` before moving on.** The whole operator pattern is in ~15 lines of
shell:

```
loop forever:
    read desired state from the API      (spec)
    make the world match it              (create/update child objects)
    write back what actually happened    (status)
```

A real operator written with kubebuilder or Operator SDK differs in engineering quality — it uses
watches instead of polling, work queues, leader election, `ownerReferences` for garbage collection,
retries with backoff, and typed Go structs instead of `custom-columns` parsing. But the *idea* is
exactly what you just read.

**Prove the loop is real.** Create a new Chiya and watch the controller pick it up within 5 seconds:

```bash
kubectl create -f - <<'EOF'
apiVersion: chiyashop.dev/v1alpha1
kind: Chiya
metadata:
  name: evening-lemon
  namespace: chiya-prod
spec:
  variety: lemon
  servings: 3
EOF

kubectl get chiya -n chiya-prod evening-lemon -o yaml | tail -10
```

**Then break it.** Delete the ConfigMap the controller created and watch it come back:

```bash
kubectl delete configmap -n chiya-dev recipe-morning-masala
sleep 10
kubectl get configmap -n chiya-dev recipe-morning-masala
```

That is *reconciliation*, and it is the single most important idea in Kubernetes. Nothing "handled
the delete event". The loop simply ran again and noticed reality did not match the spec.

**Now break the permissions.** Edit the ClusterRole and remove `configmaps` from it:

```bash
kubectl edit clusterrole chiya-controller     # delete the configmaps rule, save
kubectl delete configmap -n chiya-dev recipe-office-black
kubectl logs -n chiya-system deploy/chiya-controller --tail=20
```

You will see `Error from server (Forbidden)`. Every operator you install in Part 4 ships a
ClusterRole exactly like this one, and "the operator is silently doing nothing" is nearly always an
RBAC problem. Put the rule back afterwards (`kubectl apply -f 03-crd/05-controller-rbac.yaml`).

### Checkpoint 3

- What exactly does a CRD give you? What does it *not* give you?
- Why must `metadata.name` be `plural.group`?
- Why is `status` a subresource instead of just another field?
- Your CR field disappeared after apply. Why, and which flag would have warned you?
- Define "reconciliation loop" in one sentence.

---

## 5. Part 4 — Operators and their `values.yaml`

**Definition.** An operator is a **CRD (or several) + a controller that acts on it**, packaged
together and usually installed with Helm. That is the entire idea. You built a bad one in Part 3;
now you install three good ones.

The mental split that trips people up:

| | Written by | Configures | Changed by |
|---|---|---|---|
| `values.yaml` | you, at install time | **the operator itself** — its image, replicas, RBAC, resources, feature flags | `helm upgrade` |
| Custom resource | you, at any time | **the thing the operator manages** — a certificate, a database, a Prometheus | `kubectl apply` |

If you find yourself editing `values.yaml` to create a database, you have confused the two.

### 5.1 cert-manager — the smallest useful operator

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo jetstack/cert-manager --versions | head -5     # check what's current

helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  -f 04-operators/cert-manager/values.yaml

kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager
```

Three Pods (controller, webhook, cainjector) and six new CRDs. Read
`04-operators/cert-manager/values.yaml` — notice `crds.keep: true`. **Deleting a CRD deletes every
object of that type in the cluster.** Uninstalling a chart that also removes its CRDs is how people
delete all their production certificates by accident.

Now use the API it installed:

```bash
kubectl apply -f 04-operators/cert-manager/issuer-and-cert.yaml
kubectl get clusterissuers
kubectl get certificates -A
kubectl get secret -n chiya-dev chiya-web-tls
```

You created a `Certificate` object; the operator created a **Secret** containing a real key pair.
Look at it:

```bash
kubectl get secret -n chiya-dev chiya-web-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -subject -issuer -dates
```

Watch the operator work by describing the Certificate — the events are a narrative:

```bash
kubectl describe certificate -n chiya-dev chiya-web-tls
```

**Try this:** delete the Secret. It comes back. Same reconciliation loop as your shell controller.

### 5.2 CloudNativePG — an operator that runs something stateful

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm upgrade --install cnpg cnpg/cloudnative-pg \
  -n cnpg-system --create-namespace \
  -f 04-operators/cloudnative-pg/values.yaml

kubectl get pods -n cnpg-system
kubectl get crds | grep cnpg
```

One operator Pod, doing nothing. Give it a `Cluster`:

```bash
kubectl apply -f 04-operators/cloudnative-pg/chiya-db-cluster.yaml
kubectl get cluster -n chiya-db -w        # wait for "Cluster in healthy state"
```

Then look at everything you did **not** write:

```bash
kubectl get all,pvc,secrets -n chiya-db
```

Two Pods with streaming replication, PVCs, three Services (`-rw` primary, `-ro` replicas, `-r` all)
and generated credentials — from 25 lines of YAML. Compare that with
`01-jobs/06-chiya-db.yaml`, where you got a single Postgres with no replication and no persistence
for about the same amount of typing.

Connect to it:

```bash
kubectl get secret -n chiya-db chiya-pg-app -o jsonpath='{.data.password}' | base64 -d; echo
kubectl exec -it -n chiya-db chiya-pg-1 -- psql -U postgres -d chiya -c '\l'
```

**The failover demo.** Find the primary (the Pod behind the `-rw` Service), then delete it:

```bash
kubectl get pods -n chiya-db -l cnpg.io/instanceRole=primary
kubectl delete pod -n chiya-db <primary-pod>
kubectl get cluster -n chiya-db -w
```

The operator promotes the standby in seconds and rebuilds the old primary as a replica. Nobody
paged anybody. **That is what an operator buys you:** it encodes the operational knowledge of a
Postgres DBA — failover, backups, minor-version upgrades — as a control loop.

### 5.3 kube-prometheus-stack — an operator you configure heavily

> Heaviest install of the day (~1.5 GB RAM). Skip if your laptop is struggling.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f 04-operators/kube-prometheus-stack/values.yaml

kubectl get pods -n monitoring -w
```

While it starts, **read the values file.** This chart is a good example of how much a `values.yaml`
can carry: it turns whole components on and off (`alertmanager.enabled`), sets resources, and
configures the operator's *selectors*.

Those selectors are the classic trap:

```yaml
serviceMonitorSelectorNilUsesHelmValues: false
```

Leave that at its default `true` and Prometheus will only scrape ServiceMonitors labelled with the
Helm release name. Your perfectly correct ServiceMonitor is then ignored, with no error anywhere.
Hours have been lost to this.

Now scrape something of your own:

```bash
kubectl apply -f 04-operators/kube-prometheus-stack/podinfo-servicemonitor.yaml
kubectl get servicemonitor -A
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open <http://localhost:9090/targets> and find `chiya-dev/chiya-web`. Then query `up{job="chiya-web"}`.

**Notice what you did not do:** you never edited `prometheus.yml`. The operator watches
ServiceMonitor objects, regenerates the scrape config, stores it in a Secret and hot-reloads
Prometheus. Prove it:

```bash
kubectl get prometheus -n monitoring -o yaml | grep -A5 serviceMonitorSelector
kubectl get secret -n monitoring prometheus-kube-prometheus-stack-prometheus -o \
  jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | grep -A5 chiya-web
```

Grafana, if you want it:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# admin / chiya123  (from values.yaml)
```

### 5.4 Day-2: changing an operator's configuration

You installed cert-manager with its ServiceMonitor disabled because the CRD did not exist yet. It
does now:

```bash
helm upgrade cert-manager jetstack/cert-manager -n cert-manager \
  -f 04-operators/cert-manager/values.yaml \
  --set prometheus.enabled=true --set prometheus.servicemonitor.enabled=true

kubectl get servicemonitor -n cert-manager
```

**Two lessons:**

1. `helm upgrade` with the same `-f values.yaml` is how you make day-2 changes. Never `kubectl edit`
   a Deployment that Helm owns — the next upgrade silently reverts you.
2. `--set` is fine for a demo, but in real life it goes **in the values file**, in Git. If it is not
   in Git, it does not exist.

### Checkpoint 4

- Define "operator" in one sentence, using the words CRD and controller.
- Which do you edit to add a database: `values.yaml` or a custom resource?
- What happens when you delete a CRD that has objects?
- Why did the ServiceMonitor get ignored?
- How do you change an operator's own resource limits after installation?

---

## 6. The vocabulary, in one table

| Term | What it actually is |
|---|---|
| **Job** | a controller that runs Pods until N succeed, then stops |
| **CronJob** | a controller that creates Jobs on a schedule |
| **Namespace** | a name-scoping boundary you can hang policy on |
| **ResourceQuota** | a namespace-wide ceiling on resource sums and object counts |
| **LimitRange** | per-container/per-PVC defaults and min/max |
| **CRD** | a new type registered with the API server: schema + storage, no behaviour |
| **CR** | one object of that type |
| **Controller** | a loop that makes the world match a spec, and reports back in status |
| **Operator** | a CRD + a controller for it, packaged together |
| **`values.yaml`** | how *the operator* is deployed |
| **custom resource** | how *the thing the operator manages* is configured |

---

## 7. Challenges

Do at least two. They are ordered by difficulty.

1. **CronJob hygiene.** Add `activeDeadlineSeconds`, `startingDeadlineSeconds` and history limits
   to a CronJob and explain to your neighbour what each one protects against.
2. **Prod is stricter.** `chiya-prod` has `pod-security.kubernetes.io/enforce: restricted`. Deploy
   `chiya-web` there and read the rejection. Then fix it by adding a `securityContext`
   (`runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`,
   `seccompProfile.type: RuntimeDefault`).
3. **Own the children.** Add `ownerReferences` to the ConfigMap your shell controller creates, so
   that deleting a `Chiya` deletes its recipe ConfigMap automatically. (Hint: you need the
   Chiya's `uid`.)
4. **Version your API.** Add a `v1beta1` to the Chiya CRD with a new optional field, mark it
   `storage: true` and `v1alpha1` `storage: false`, with `conversion.strategy: None`. Create an
   object as `v1alpha1`, read it back as `v1beta1`. Then explain why `None` is only safe when the
   schemas are compatible.
5. **Quota-aware CronJob.** Put the CronJob from Part 1 into `chiya-dev` and set
   `count/jobs.batch: 1`. Make a run fail *because of the quota*, find the error (hint: it is on
   the CronJob's events, not the Job's), and fix it with history limits.
6. **Backup the operator way.** Give the CNPG `Cluster` a `ScheduledBackup` custom resource
   pointing at a MinIO Pod. Notice that you write a schedule into a CR, and the operator creates
   the Jobs — Part 1 and Part 4 close the circle.

---

## 8. Cleanup

```bash
bash 99-cleanup/cleanup.sh
```

Order matters: custom resources before CRDs, CRDs before uninstalling the operator. If something
hangs on deletion for more than a minute it is a **finalizer** — check with
`kubectl get <thing> -o yaml | grep -A3 finalizers`, and understand that the operator being gone is
usually the reason nothing is removing it.

Nuclear option:

```bash
minikube delete --profile jobs-lab
```

---

## 9. Cheat sheet

```bash
# Jobs
kubectl get jobs -n NS
kubectl logs -n NS job/NAME
kubectl create job NAME --from=cronjob/CRONJOB          # run a CronJob now
kubectl patch cronjob NAME -p '{"spec":{"suspend":true}}'
kubectl delete job NAME --cascade=orphan                # keep the Pods for debugging

# Quotas
kubectl describe quota -n NS
kubectl describe limitrange -n NS
kubectl get events -n NS --sort-by=.lastTimestamp
kubectl describe rs -n NS -l app=X                      # where quota errors actually appear

# CRDs
kubectl get crds
kubectl explain KIND.spec
kubectl api-resources --api-group=chiyashop.dev
kubectl get KIND -A -o wide
kubectl apply -f x.yaml --dry-run=server                # catch pruning/validation early

# Operators
helm search repo CHART --versions
helm get values RELEASE -n NS                           # what was I actually installed with?
helm get values RELEASE -n NS --all                     # including chart defaults
helm upgrade RELEASE CHART -n NS -f values.yaml
helm history RELEASE -n NS
helm rollback RELEASE 1 -n NS
```

Rules worth writing on the wall:

1. If a Deployment made no Pods, the error is on the **ReplicaSet**.
2. If a CR field vanished, the **schema pruned it**.
3. If an operator does nothing, check its **logs**, then its **RBAC**.
4. If a ServiceMonitor is ignored, check the **selector**.
5. Never `kubectl edit` something Helm owns.
