# Day 2 — Deployments, Self-Healing & Rolling Updates

**Time:** ~2.5 hours · **You will leave able to:** run a self-healing, scalable workload; roll out a new version with zero downtime; roll it back; and diagnose a rollout that's stuck.

> **Yesterday's cliffhanger:** you deleted a bare Pod and nothing brought it back. Today we fix that permanently. Cluster still running from Day 1? Good. If not: `minikube start` and check `kubectl get nodes`.

---

## Part 1 — The mental model

A **Deployment** doesn't run your pods directly. It creates a **ReplicaSet**, and the ReplicaSet's only job is: *"keep exactly N pods matching this label alive, forever."* That control loop is what makes Kubernetes feel alive — kill a pod and a new one appears in seconds.

```
Deployment  ──manages──▶  ReplicaSet  ──manages──▶  Pods (xN)
  (rollouts, history)       (count = N)               (the actual app)
```

The link between each layer is **labels**, never names. Burn that in — it explains today's self-healing *and* tomorrow's networking *and* the most common capstone bug.

---

## Part 2 — Guided lab: run, scale, self-heal (~35 min)

```bash
kubectl apply -f deployment.yaml
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| Watch 3 pods appear | `:deploy` ↵, then `:pods` | `kubectl get deploy,rs,pods` |
| See the whole chain | on the deployment, press `d` (describe) | `kubectl describe deploy podinfo` |
| **Self-heal:** kill a pod | select a pod, `ctrl-d` to delete it | `kubectl delete pod <name>` |
| Watch it come back | stay on `:pods` | `kubectl get pods -w` |
| Scale up to 5 | `:deploy`, select podinfo, press `s`, enter 5 | `kubectl scale deploy podinfo --replicas=5` |
| Scale back to 3 | same, enter 3 | `kubectl scale deploy podinfo --replicas=3` |

When you deleted that pod, a replacement appeared almost instantly — **that** is the thing a bare Pod couldn't do. Nobody typed a command; the ReplicaSet noticed reality ≠ desired and fixed it.

---

## Part 3 — Rolling update: change the version live (~30 min)

podinfo colors its UI by version, so a rollout is *visible*. Port-forward first so you can watch it flip:

```bash
kubectl port-forward deploy/podinfo 9898:9898   # leave running; open http://localhost:9898
```

In another terminal, roll to a different version and watch the pods cycle in K9s (`:pods`):

```bash
kubectl set image deploy/podinfo podinfo=stefanprodan/podinfo:6.13.0
kubectl rollout status deploy/podinfo
```

Because the manifest sets `maxUnavailable: 0` / `maxSurge: 1`, Kubernetes brings up a new pod, waits for its **readiness probe**, *then* retires an old one — so the service never drops to zero. Refresh the browser and watch the version badge change. Now undo it:

```bash
kubectl rollout history deploy/podinfo
kubectl rollout undo deploy/podinfo
```

---

## Part 4 — Challenge (no table) (~15 min)

1. Scale to 4 replicas using **K9s only**.
2. Roll the image forward to `6.14.0` again using **kubectl only**, and watch the rollout status.
3. Delete the underlying **ReplicaSet** (not the Deployment). What happens, and why?
   <details><summary>answer</summary>The Deployment immediately recreates a ReplicaSet — because the Deployment is the higher-level controller whose desired state includes "a ReplicaSet exists." You deleted a child; the parent rebuilt it. This is the control loop one level up.</details>

---

## Part 5 — Break-fix: the stuck rollout (~25 min)

Trigger a rollout to a broken image:

```bash
kubectl apply -f deployment-badtag.yaml
kubectl rollout status deploy/podinfo   # this will hang — Ctrl-C after ~30s
```

Diagnose using only the cluster. In K9s `:pods`, you'll see old pods **still Running and serving** while a new pod is stuck.

- What status is the new pod in? (`d` → Events)
- **Key question:** is your app down right now? Check the browser / port-forward.
- Why did `maxUnavailable: 0` just save you?

<details>
<summary><b>What you should have found</b></summary>

The new pod is `ImagePullBackOff` (bad tag). But the **app never went down** — because `maxUnavailable: 0` means Kubernetes refuses to remove a healthy old pod until a new one is Ready, and the new one never becomes Ready. So the rollout is *stuck*, not *broken*. This is a feature: a bad deploy stalls instead of taking you offline.

**Fix:** `kubectl rollout undo deploy/podinfo` (or apply the good `deployment.yaml`). The lesson: a stuck rollout with a healthy app is a good failure mode — investigate calmly, then roll back.

</details>

---

## Recap — checks for understanding

1. Deployment, ReplicaSet, Pod — which one heals dead pods, and which one handles version rollouts?
2. What does the readiness probe have to do with a *zero-downtime* rolling update?
3. You ran `kubectl scale` to 5, but the YAML still says `replicas: 3`. If you now `kubectl apply -f deployment.yaml`, what happens?
4. When is `rollout undo` the right first move, and when should you dig into Events first?

---

## Cleanup

```bash
kubectl delete -f deployment.yaml --ignore-not-found
```

**Tomorrow (Day 3):** three pods, three IPs that change every restart — how does anything *find* them? We put a stable **Service** in front and untangle cluster DNS.
