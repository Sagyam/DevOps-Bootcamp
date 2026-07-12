# Day 1 — The Cluster & the Pod

**You will leave able to:** navigate a live cluster in K9s, run the equivalent kubectl commands blind, explain what a Pod is, and diagnose a pod that won't start.

> **How this week works.** You will almost never write YAML — it's all provided in these folders. Your job is to **apply it, watch what happens in K9s, run the matching kubectl command, then break it and fix it.** Every K9s action below has a kubectl twin. Learn both: K9s so you can *see* the cluster, kubectl so you can *drive* it over SSH with no GUI.

---

## Part 0 — Bring up your cluster (~20 min)

Run this once at the start of the day. We give it real resources now so we don't run out of memory on Day 5.

```bash
minikube start --cpus=4 --memory=6144 --driver=docker

# Addons we'll need later this week — enable them now:
minikube addons enable metrics-server   # Day 6
minikube addons enable ingress          # Day 8
minikube addons enable dashboard        # Day 8 (optional)

# Sanity — all three must succeed before you continue:
kubectl cluster-info
kubectl get nodes -o wide
k9s
```

You should see exactly **one node**, `Ready`. Quit K9s with `:q` for now.

<details>
<summary><b>OS notes — read the one for your machine if <code>minikube start</code> fails</b></summary>

- **Linux:** the `docker` driver runs natively on Docker Engine. If you get a permissions error, make sure your user is in the `docker` group (`sudo usermod -aG docker $USER`, then log out/in).
- **macOS:** Docker Desktop must be **running** before `minikube start`. If start hangs or OOMs, open Docker Desktop → Settings → Resources and give it at least **6 GB RAM / 4 CPUs** (minikube borrows from Docker's pool).
- **Windows:** use Docker Desktop with the **WSL2** backend, and run `minikube` from the same shell (PowerShell or WSL — pick one and stay in it). Same 6 GB / 4 CPU minimum in Docker Desktop settings.
- **Any OS, "not enough memory":** lower `--memory=6144` to `4096`. It's tighter but works through Day 4; bump it back up before Day 5.

</details>

---

## Part 1 — The mental model (know this cold)

- **You never touch containers directly.** You send desired state to the **API server** (`kind: Pod`, `kind: Deployment`, …). Controllers on the cluster constantly work to make reality match what you asked for. This loop — *desired vs actual* — is the single most important idea in Kubernetes.
- **Declarative, not imperative.** You describe *what* you want in a file and run `kubectl apply`. You don't script the *how*. "Make the cluster look like this file."
- **A Pod is the smallest deployable unit** — one (usually) container, wrapped so Kubernetes can schedule it, give it an IP, and attach storage. You rarely create Pods directly in production (you'll see why at the very end of today), but understanding the Pod is the foundation for everything else.

---

## Part 2 — Guided lab: run and inspect a Pod (~40 min)

Apply the provided Pod:

```bash
kubectl apply -f pod.yaml
```

Now open K9s (`k9s`) and do each row below **in K9s first**, then run the **kubectl twin** to see they're the same thing.

| Goal | In K9s | kubectl twin |
|---|---|---|
| Find your pod | type `:pods` ↵, watch `Pending → ContainerCreating → Running` | `kubectl get pods -w` |
| Understand its state | select the pod, press **`d`** (describe) — scroll to **Events** at the bottom | `kubectl describe pod podinfo` |
| Read its logs | press **`l`** | `kubectl logs podinfo` |
| Get a shell inside | press **`s`** — you're now inside the container | `kubectl exec -it podinfo -- sh` |
| Hit the app from inside | (in that shell) `wget -qO- localhost:9898/healthz` | same |
| See the live spec | press **`y`** (YAML) | `kubectl get pod podinfo -o yaml` |
| Reach the app from your laptop | press **`shift-f`**, accept `9898`, then open http://localhost:9898 | `kubectl port-forward pod/podinfo 9898:9898` |

> **The `d` key is your best friend all week.** When anything is wrong, `describe` and read the **Events** at the bottom. Kubernetes almost always tells you exactly what's wrong there — people just don't look.

Open http://localhost:9898 in a browser while the port-forward is running. Note the **version badge** — remember its color/number, it becomes important on Day 2.

---

## Part 3 — The punchline: a bare Pod does NOT heal (~10 min)

Delete the pod:

```bash
kubectl delete pod podinfo      # or press ctrl-d on it in K9s
```

Watch `:pods` in K9s. **It's gone. Nothing brings it back.** Nobody was watching it.

This is the whole reason Deployments exist (Day 2). A raw Pod is a single, mortal thing. Real workloads are managed by a controller that notices when a pod dies and makes a new one. You just felt the problem that the rest of the week solves.

---

## Part 4 — Three tools you'll reach for constantly (~20 min)

```bash
# 1. Built-in schema docs — never guess a YAML field again:
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.ports

# 2. Everything this cluster knows how to run:
kubectl api-resources | less

# 3. Namespaces — the cluster's folders. Your stuff lives in 'default'.
#    The cluster's own guts live in 'kube-system' — go look:
kubectl get pods --all-namespaces
```

In K9s: type `:ns` to list namespaces, `<enter>` on `kube-system` to see the components that *are* Kubernetes (CoreDNS, kube-proxy, the API server, the scheduler). You've been standing on top of these the whole time.

---

## Part 5 — Challenge (do this without the table) (~15 min)

1. Re-apply `pod.yaml`.
2. Using **only kubectl** (no K9s), find the pod's internal IP address.
   <details><summary>hint</summary><code>kubectl get pod podinfo -o wide</code></details>
3. Using **only K9s**, get a shell in the pod and print its environment variables.
4. What namespace is your pod in, and how can you tell from the `describe` output?

---

## Part 6 — Break-fix (~20 min)

Apply the broken pod:

```bash
kubectl apply -f pod-broken.yaml
```

It will **not** reach `Running`. Your task: figure out why using **only the cluster's own signals** — do not open `pod-broken.yaml` looking for the answer.

- In K9s, watch the STATUS column on `podinfo-broken`. What does it say?
- Press **`d`** and read the **Events**. What is Kubernetes trying and failing to do?
- What's the difference between the `ErrImagePull` and `ImagePullBackOff` states you might see cycle by?

<details>
<summary><b>What you should have found</b></summary>

The status is `ImagePullBackOff` (after an initial `ErrImagePull`). The Events say Kubernetes tried to pull `stefanprodan/podinfo:6.14.0-does-not-exist` and failed — that tag doesn't exist in the registry. `BackOff` means Kubernetes is deliberately waiting longer and longer between retries so it doesn't hammer the registry.

**The fix in real life:** correct the image tag. The lesson: *the YAML was valid and applied cleanly — the failure only showed up at runtime, in the Events.* This pattern (valid config, runtime failure, answer in the Events) repeats all week.

</details>

Clean it up: `kubectl delete pod podinfo-broken`

---

## Recap — checks for understanding

Answer these out loud before you leave:

1. Why did `podinfo` **not** come back after you deleted it? What would have to be different for it to heal?
2. What's the difference between `kubectl apply` and `kubectl create`, in one sentence each?
3. A pod is stuck and not `Running`. What is the **first** command (or K9s key) you reach for, and where in the output do you look?
4. What does the `-w` flag do on `kubectl get`, and what's the K9s equivalent?

---

## Cleanup

```bash
kubectl delete -f pod.yaml --ignore-not-found
kubectl delete -f pod-broken.yaml --ignore-not-found
# Leave the cluster running — we reuse it tomorrow. (minikube stop to pause it.)
```

**Tomorrow (Day 2):** we replace this mortal Pod with a **Deployment** — and finally make things heal, scale, and update without downtime.