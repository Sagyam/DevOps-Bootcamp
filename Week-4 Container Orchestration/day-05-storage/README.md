# Day 5 — Storage: PVs, PVCs & StatefulSets

**Time:** ~2.5 hours · **You will leave able to:** give a pod storage that survives restarts, explain the PVC → PV → StorageClass chain, run a database as a StatefulSet with stable identity, and diagnose a pod stuck Pending on storage.

> Bump your cluster memory if you dropped it earlier — Postgres needs a bit of room. `minikube start` if it's stopped.

---

## Part 1 — The mental model

Pod filesystems are **ephemeral** — restart a pod and everything it wrote is gone. To persist data you *claim* storage:

```
PersistentVolumeClaim  ──"I want 100Mi RWO"──▶  StorageClass  ──provisions──▶  PersistentVolume
   (what YOU write)                                (the "how")                    (the actual disk)
        │
        └──▶ mounted into your pod at a path
```

You almost never create a PV by hand. You write a **PVC** (a request), and a **StorageClass** (minikube ships one called `standard`) dynamically provisions a matching PV and binds it. That decoupling is the whole design.

A **StatefulSet** is like a Deployment but for things with identity — each pod gets a stable name (`postgres-0`) and its *own* persistent volume that follows it across restarts.

---

## Part 2 — Guided lab: persistence with a plain PVC (~30 min)

```bash
kubectl apply -f pvc.yaml     # creates a PVC + a busybox pod that writes a file
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| Watch the PVC bind | `:pvc` — status `Pending → Bound` | `kubectl get pvc -w` |
| See the auto-created PV | `:pv` | `kubectl get pv` |
| Read the file the pod wrote | `:pods` → `writer` → `s`, then `cat /data/log.txt` | `kubectl exec writer -- cat /data/log.txt` |

Now the proof. **Delete the pod, recreate it, and confirm the file survived:**

```bash
kubectl delete pod writer
kubectl apply -f pvc.yaml                       # recreates only the pod; the PVC stays Bound
kubectl exec writer -- cat /data/log.txt        # your line from "first boot" is STILL there
```

The pod died; the data didn't. That's persistence. (Delete the *PVC* and it's gone for good — the PVC is the lifecycle handle for the data.)

---

## Part 3 — StatefulSet: Postgres with stable identity (~40 min)

```bash
kubectl apply -f postgres-headless-svc.yaml
kubectl apply -f postgres-statefulset.yaml
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| Watch ordered creation | `:sts` then `:pods` — `postgres-0` **then** `postgres-1` | `kubectl get pods -w -l app=postgres` |
| See per-pod PVCs | `:pvc` — `data-postgres-0`, `data-postgres-1` | `kubectl get pvc` |
| Each pod's stable DNS | `:pods` → `postgres-0` → `s`, `nslookup postgres-0.postgres` | — |

**The persistence test that matters for a DB.** Write a row, kill the pod, confirm it survived:

```bash
kubectl exec -it postgres-0 -- psql -U postgres -d shortlink \
  -c "CREATE TABLE t(x text); INSERT INTO t VALUES ('survives restarts');"
kubectl delete pod postgres-0                    # StatefulSet recreates it with the SAME name + SAME volume
kubectl exec -it postgres-0 -- psql -U postgres -d shortlink -c "SELECT * FROM t;"
# -> 'survives restarts'
```

`postgres-0` came back with its identity *and* its data intact. A Deployment can't promise that; a StatefulSet can. (Note: these two Postgres pods are independent instances — we run two only to make ordering and per-pod storage visible, not to demonstrate replication.)

---

## Part 4 — Challenge (~15 min)

1. What are the exact DNS names of the two Postgres pods? Prove it from inside the `client`-style shell.
2. Delete `postgres-1`. Which volume does the replacement reattach to, and how can you tell?
3. Why does a StatefulSet need the *headless* Service (`clusterIP: None`) rather than a normal one?
   <details><summary>answer</summary>A headless service doesn't load-balance across a single VIP — it hands back each pod's individual DNS record, which is exactly what stable per-pod identity requires. A normal ClusterIP would hide the individuals behind one address.</details>

---

## Part 5 — Break-fix: Pending forever (~25 min)

```bash
kubectl apply -f pvc-pending.yaml
```

- In K9s `:pvc`, what status is `data-pending` stuck in?
- Press `d` on it → Events. What's it waiting for?

<details>
<summary><b>What you should have found</b></summary>

The PVC is stuck `Pending`. The Events say there's no StorageClass named `fast-ssd` (this cluster only has `standard`), so nothing can provision a volume — and any pod trying to mount this PVC would be `Pending` too.

**The habit:** a `Pending` pod is almost always a **scheduling** or **storage** problem. `describe` the pod *and* the PVC and read the Events. Fix: use `standard` (or delete the `storageClassName` line to get the default).

</details>

---

## Recap — checks for understanding

1. Walk the chain: you write a PVC — what provisions the actual disk, and what binds to what?
2. What's the difference between deleting a *pod* that uses a PVC vs deleting the *PVC*?
3. Name two things a StatefulSet gives you that a Deployment doesn't.
4. A pod is `Pending`. What two objects do you describe, and what are you looking for?

---

## Cleanup

```bash
kubectl delete -f postgres-statefulset.yaml -f postgres-headless-svc.yaml \
  -f pvc.yaml -f pvc-pending.yaml --ignore-not-found
# StatefulSet PVCs are NOT auto-deleted — clean them up explicitly:
kubectl delete pvc -l app=postgres --ignore-not-found
kubectl delete pvc data --ignore-not-found
```

**Tomorrow (Day 6):** we make workloads defend themselves — liveness/readiness **probes**, CPU/memory **requests & limits**, and an **HPA** that scales under load. Plus two of the most-Googled pod states: `CrashLoopBackOff` and `OOMKilled`.
