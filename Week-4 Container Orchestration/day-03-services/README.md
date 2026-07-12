# Day 3 — Services, DNS & Networking

**Time:** ~2.5 hours · **You will leave able to:** expose pods behind a stable name, explain ClusterIP vs NodePort, reason about cluster DNS, and diagnose the single most common networking bug in Kubernetes (empty endpoints).

> Cluster running? `kubectl get nodes`. Then bring up today's workload.

---

## Part 1 — The mental model

Pods are cattle: they die, restart, and get **new IPs** every time. So you never talk to a pod by IP. A **Service** gives you one stable virtual IP + DNS name that load-balances across whatever pods currently match its **selector**.

```
Service (stable IP + DNS: "podinfo")
   │  selector: app=podinfo
   ▼
Endpoints  ◀── kubernetes keeps this list in sync automatically
   │
   ├─▶ podinfo-abc (10.244.0.5)
   ├─▶ podinfo-def (10.244.0.6)
   └─▶ podinfo-ghi (10.244.0.7)
```

The **Endpoints** object is the hidden hero — it's the live list of pod IPs behind the Service. When networking breaks, this is where you look. Remember it.

---

## Part 2 — Guided lab: ClusterIP + DNS (~35 min)

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service-clusterip.yaml
kubectl apply -f client.yaml        # a throwaway pod with curl/nslookup
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| See the Service | `:svc` | `kubectl get svc podinfo` |
| **See the endpoints** (the pod IPs) | `:endpoints` (or `:ep`) | `kubectl get endpoints podinfo` |
| Get a shell in the client | `:pods` → select `client` → `s` | `kubectl exec -it client -- sh` |
| Reach the app **by name** (from client) | `curl -s podinfo/` | same |
| Prove DNS resolves | `nslookup podinfo` | same |
| Hit it 10× — see load-balancing | `for i in $(seq 10); do curl -s podinfo/ \| grep hostname; done` | same |

That last one returns different pod hostnames — the Service is spreading requests across all three pods. And notice you reached it as just `podinfo` — in-namespace, the short name works (full name: `podinfo.default.svc.cluster.local`).

---

## Part 3 — NodePort: reach it from outside (~20 min)

ClusterIP is cluster-internal only. **NodePort** opens a fixed port on the node:

```bash
kubectl apply -f service-nodeport.yaml
minikube service podinfo-np --url     # prints an externally-reachable URL
```

Open that URL in your browser. (In K9s, `:svc` shows the NodePort in the PORTS column — `80:30080/TCP`.)

| Type | Reachable from | Use it for |
|---|---|---|
| ClusterIP | inside the cluster only | service-to-service (99% of the time) |
| NodePort | outside, via node IP + high port | dev/testing, or under a load balancer |
| (LoadBalancer / Ingress) | the real front door | production external traffic — **Day 8** |

---

## Part 4 — Challenge (no table) (~15 min)

1. From the `client` pod, reach podinfo's health endpoint by name.
   <details><summary>hint</summary><code>curl -s podinfo/healthz</code></details>
2. Scale the deployment to 5 and re-check `:endpoints`. How many IPs now? Who updated that list?
3. Using **kubectl only**, find which node port the NodePort service opened, without using `minikube service`.

---

## Part 5 — Break-fix: the Service that routes nowhere (~30 min)

```bash
kubectl apply -f service-bad-selector.yaml
kubectl exec -it client -- curl -m 5 podinfo-bad/     # hangs, then times out
```

The Service applied with zero errors. curl just times out. Diagnose:

- In K9s, `:svc` → select `podinfo-bad` → `d`. Anything obviously wrong?
- Now `:endpoints` and look at `podinfo-bad`. What's different from `podinfo`?

<details>
<summary><b>What you should have found</b></summary>

`podinfo-bad` has **no endpoints** — the ENDPOINTS column is empty (`<none>`). Its selector is `app=podinfoo` (typo), which matches no pods, so the Service has nothing to route to and every request hangs.

This is *the* classic Kubernetes networking bug, and it **never errors on apply** — the Service is valid, it just points at nothing. **The habit that saves you:** when a Service is unreachable, check its endpoints *first*. Empty endpoints = selector/label mismatch. Fix the selector to `app=podinfo` and the endpoints populate instantly.

</details>

---

## Recap — checks for understanding

1. Why can't you just talk to a pod by its IP address?
2. What is the Endpoints object, and who keeps it updated?
3. A teammate says "my Service returns connection timeouts." What's the *first* thing you check, and what does an empty result mean?
4. ClusterIP vs NodePort — when would you reach for each?

---

## Cleanup

```bash
kubectl delete -f deployment.yaml -f service-clusterip.yaml -f service-nodeport.yaml \
  -f service-bad-selector.yaml -f client.yaml --ignore-not-found
```

**Tomorrow (Day 4):** stop baking config into images. We externalize settings with **ConfigMaps** and handle passwords with **Secrets** — and see why base64 is not encryption.
