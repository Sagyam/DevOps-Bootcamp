# Day 6 — Health Probes, Resources & Autoscaling

**Time:** ~3 hours · **You will leave able to:** configure liveness/readiness probes, set resource requests/limits, autoscale under load with an HPA, and diagnose the two states everyone Googles — `CrashLoopBackOff` and `OOMKilled`.

> This is the "make it production-real" day. Confirm metrics-server is on: `kubectl top nodes` should return numbers (if not: `minikube addons enable metrics-server`, wait ~1 min).

---

## Part 1 — The mental model

Kubernetes can only keep your app healthy if you *tell it what healthy means*.

- **Liveness probe** — "is it wedged?" Fails → **restart** the container.
- **Readiness probe** — "is it ready for traffic?" Fails → **pull it out of the Service** (no restart).
- **Requests** — what the scheduler *reserves* for the pod (used for placement and HPA math).
- **Limits** — the hard ceiling. Exceed memory → **OOMKilled**. Exceed CPU → throttled.

Get probes wrong and a healthy app restart-loops. Get limits wrong and the kernel kills you. Both happen today, on purpose.

---

## Part 2 — Guided lab: probes & resources (~35 min)

```bash
kubectl apply -f deployment-probes.yaml     # podinfo with liveness + readiness + requests/limits + a Service
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| See probe config | `:pods` → pod → `d`, find Liveness/Readiness | `kubectl describe pod -l app=podinfo` |
| See resource usage | `:pods` → press `↑`/scroll to CPU/MEM cols, or `:pu` | `kubectl top pods` |

**Watch readiness do its job.** podinfo can be told to report unready on demand:

```bash
kubectl port-forward deploy/podinfo 9898:9898
curl -X POST localhost:9898/readyz/disable     # tell this pod: "say NOT ready"
```

In K9s `:pods`, that pod's READY flips to `0/1` and it drops out of the Service endpoints — **but it is not restarted** (readiness ≠ liveness). Re-enable:

```bash
curl -X POST localhost:9898/readyz/enable
```

**Now watch liveness do its job.** Crash the process:

```bash
curl localhost:9898/panic     # podinfo exits 255; liveness fails; Kubernetes restarts it
```

Watch the RESTARTS count tick up in `:pods`. Liveness caught a dead process and healed it.

---

## Part 3 — Autoscaling under load (~35 min)

```bash
kubectl apply -f hpa.yaml        # target: 50% CPU, 2→8 replicas
kubectl apply -f loadgen.yaml    # hammers the podinfo Service in a loop
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| Watch CPU climb | `:pu` (pod utilization) | `kubectl top pods` |
| Watch the HPA react | `:hpa` → `d` for the decision log | `kubectl get hpa podinfo -w` |
| Watch replicas grow | `:deploy` | `kubectl get deploy podinfo -w` |

Give it 1–3 minutes: CPU crosses 50% of the request, the HPA adds replicas toward 8. Then remove the load and watch it scale **down** (slowly — there's a stabilization window so it doesn't flap):

```bash
kubectl delete pod loadgen
```

---

## Part 4 — Challenge (~20 min)

1. Make one pod report unready and confirm — via `:endpoints` — that it left the Service's endpoint list. Then bring it back.
2. Trigger a scale-up, then a scale-down, and read the HPA's `describe` output to explain *why* it made each decision.
3. Edit the deployment's CPU **request** to `cpu: 8` and re-apply. What happens to the pods, and what does `describe` say?
   <details><summary>answer</summary>They go <code>Pending</code> — no node can satisfy an 8-core request. Events show <code>Insufficient cpu</code>. Requests drive scheduling; ask for more than exists and nothing schedules.</details>

---

## Part 5 — Break-fix #1: the CrashLoop that isn't the app's fault (~25 min)

```bash
kubectl apply -f deployment-badprobe.yaml
```

The app is perfectly fine, yet the pod keeps restarting. Diagnose:

- In K9s `:pods`, watch the STATUS and RESTARTS columns cycle.
- Press `d` → Events. What is failing, and against which path?

<details>
<summary><b>What you should have found</b></summary>

`CrashLoopBackOff`, and the Events show the **liveness probe** failing against `/health` — but podinfo's endpoint is `/healthz`. The app is healthy; the *probe* is misconfigured, so Kubernetes thinks the app is wedged and kills it every ~30s. The trap is blaming the app. Always check *what* is failing in Events — here it's the probe, not the process. Fix the path to `/healthz`.

</details>

---

## Part 6 — Break-fix #2: OOMKilled (~20 min)

```bash
kubectl apply -f deployment-oom.yaml     # tries to grab 250Mi under a 100Mi limit
```

- In K9s `:pods`, watch `memory-hog` restart.
- Press `d`. Under the container's **Last State**, what's the Reason?

<details>
<summary><b>What you should have found</b></summary>

`Last State: Terminated, Reason: OOMKilled`, `Exit Code: 137`. The container asked the kernel for more memory than its limit allowed, so it was killed and restarted — forever. In real life the fix is either a higher limit (if the app legitimately needs it) or fixing a memory leak. The signal to recognize: **137 / OOMKilled = memory limit hit.**

</details>

---

## Recap — checks for understanding

1. Liveness vs readiness — which restarts a pod, which just removes it from the Service?
2. Requests vs limits — which one does the scheduler use to place a pod, and which one gets you OOMKilled?
3. A healthy app is stuck in CrashLoopBackOff. What's your prime suspect, and where do you confirm it?
4. Your HPA won't scale even under load. Name two things that must be true for it to work at all.

---

## Cleanup

```bash
kubectl delete -f deployment-probes.yaml -f hpa.yaml -f deployment-oom.yaml \
  -f loadgen.yaml --ignore-not-found
```

**Tomorrow (Day 7):** you've hand-applied a lot of YAML this week. We package a whole multi-service app into one installable, versioned, configurable unit with **Helm**.
