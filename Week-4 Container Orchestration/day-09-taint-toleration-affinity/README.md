# Bonus Lab — The Garden

### Taints, tolerations, and affinity

You have spent nine days telling Kubernetes *what* to run. This lab is about telling it **where** — and about the two completely different mechanisms people spend their careers confusing with each other.

Same contract as every other day: **apply, observe, break, fix.** Everything is provided. You will not write YAML. Your job is to read it, run it, watch it, and explain what happened.

---

## The garden

Every idea in this lab lives inside one picture. Learn it before you touch the cluster.

| In the garden | In the cluster | Lives on | What it does |
|---|---|---|---|
| A garden bed | a **Node** | — | a machine with room to spare |
| A bee | the **Pod you want** there | — | the workload the node was set aside for |
| A mosquito | the **Pod you don't** | — | any other workload, happily squatting |
| **Mortein** (spray) | a **taint** | the **node** | repels every Pod that isn't immune |
| A gas mask | a **toleration** | the **Pod** | "that spray doesn't stop me" |
| Flower scent | **node affinity** | the **Pod** | "that's the kind of garden I want" |
| Bees avoiding each other | **pod anti-affinity** | the **Pod** | "don't put me next to my own kind" |

Two sentences to carry through the whole lab:

> **Repulsion is the garden's decision. Attraction is the insect's decision.**
>
> **A toleration is a permit, not a preference.** It removes an objection. It never creates an attraction.

If you only remember the second one, this lab has done its job.

---

## Part 0 — Bring up the garden

Taints and affinity are meaningless on a one-node cluster: there is nowhere else to go. **This lab needs three nodes.** That is different from every other day this module, so read this part properly.

```bash
# leave your existing minikube profile alone — this one is separate
minikube start -p garden --nodes 3 --cpus 2 --memory 2048

# point kubectl and K9s at it
kubectl config use-context garden

kubectl get nodes
```

You should see three nodes: `garden`, `garden-m02`, `garden-m03`. If the second and third take a while to appear, that's normal — give them a minute and re-run.

**Two things to look at before you go on.**

```bash
# 1. What taints already exist?
kubectl describe node garden | grep -A3 Taints
```

On a real cluster built with `kubeadm`, the control-plane node carries a permanent `node-role.kubernetes.io/control-plane:NoSchedule` taint — that is *why* your application never lands on it. minikube removes it so a laptop cluster is actually usable, so you will see `Taints: <none>`. Remember that difference; it surprises people the first time they touch a production cluster.

```bash
# 2. What labels does every node already have?
kubectl get nodes --show-labels
```

Note `kubernetes.io/hostname` (different per node) and `kubernetes.io/os` (identical on all three). That difference matters in Part 6, and it is the whole of Bug 5.

Now plant the flowers:

```bash
kubectl label node garden-m02 flower=marigold
kubectl label node garden-m03 flower=rose

kubectl get nodes -L flower
```

Open K9s and leave it open on `:nodes` for the rest of the lab.

> **K9s tip for this lab:** on the `:nodes` view, press `<enter>` on a node to drill into just the Pods running there. That is the fastest way to answer "where did it actually land?" — which is the question this entire lab keeps asking. (If your K9s build doesn't drill in, use `:pods` and read the NODE column instead.)

---

## Part 1 — Where do Pods land when nobody has an opinion?

```bash
kubectl apply -f manifests/01-baseline.yaml
kubectl get pods -o wide
```

| In K9s | The kubectl mirror |
|---|---|
| `:pods` → read the **NODE** column | `kubectl get pods -o wide` |
| `:nodes` → `<enter>` on a node | `kubectl get pods --field-selector spec.nodeName=garden-m02` |
| `:nodes` → `d` | `kubectl describe node garden-m02` |

**Observe.** Six Pods, spread across three nodes. Not necessarily 2/2/2 — the scheduler is balancing *requested* resources, not counting Pods. Run it a couple of times and note the distribution.

**The point.** With no rules at all, placement is decided by one question: *is there room?* Everything else in this lab is about adding a second and third question on top of that.

Leave it running.

---

## Part 2 — Spray the Mortein

```bash
kubectl taint nodes garden-m02 spray=mortein:NoSchedule
```

Read the syntax carefully, because it's unlike anything else in kubectl: `key=value:Effect`.

| In K9s | The kubectl mirror |
|---|---|
| `:nodes` → `d` on `garden-m02` → find **Taints** | `kubectl describe node garden-m02 \| grep -A3 Taints` |
| `:pods` → watch the NODE column | `kubectl get pods -o wide -w` |

**Observe.** Nothing happened. The Pods already on `garden-m02` are still there, still Running.

That is not a bug — `NoSchedule` is checked at *landing* time only. Now force a fresh landing:

```bash
kubectl rollout restart deployment/bees
kubectl get pods -o wide
```

All six now sit on `garden` and `garden-m03`. `garden-m02` is empty.

Push it further — make the other two gardens unavailable too:

```bash
kubectl taint nodes garden spray=mortein:NoSchedule
kubectl taint nodes garden-m03 spray=mortein:NoSchedule
kubectl rollout restart deployment/bees
kubectl get pods
```

Everything is `Pending`. Now go and ask *why*, in the cluster's own words:

```bash
kubectl describe pod -l app=bees | grep -A5 Events
```

You are looking for a line close to:

```
0/3 nodes are available: 3 node(s) had untolerated taint {spray: mortein}.
```

**The point.** `untolerated taint` is the phrase to burn in. When a Pod is Pending, the scheduler always tells you exactly which of its filters rejected which nodes. Read the Events; never guess.

---

## Part 3 — The mask, and the trap

Now give the bees a toleration.

```bash
kubectl apply -f manifests/02-bee-with-mask.yaml
kubectl get pods -o wide
```

**Observe.** All six schedule again. Fine. Now answer the real question:

> **Which node did they land on?**

They are spread across all three, exactly like Part 1. Not concentrated on `garden-m02`. Not preferring the tainted nodes in any way.

**The point — this is the most important paragraph in the lab.** A toleration did not *send* the bee anywhere. It removed an objection, and once every node's objection was removed, the scheduler went straight back to "is there room?". You have restored the Part 1 behaviour, nothing more.

Nine out of ten people who get this wrong in production get it wrong here, in exactly this way, and the failure is silent — the Pods are Running, so nobody looks. That is Bug 1 in the gauntlet.

Clean the extra taints off the two gardens you don't need sprayed:

```bash
# note the trailing minus — that is how you remove a taint
kubectl taint nodes garden spray=mortein:NoSchedule-
kubectl taint nodes garden-m03 spray=mortein:NoSchedule-
```

---

## Part 4 — The scent

Attraction is a different field entirely, and it lives on the Pod.

### 4a — Hard affinity

```bash
kubectl apply -f manifests/03-bee-required-affinity.yaml
kubectl get pods -o wide
```

**Observe.** All four Pods on `garden-m02` — the node you labelled `flower=marigold`, and also the node that is still sprayed. Both mechanisms are now in play and they are doing different jobs: the toleration got the bee past the spray, the affinity is what actually chose the destination.

Now break it deliberately:

```bash
kubectl label node garden-m02 flower=orchid --overwrite
kubectl get pods -o wide
```

**Observe.** Nothing moved. The Pods are still there, still Running, on a node that no longer matches their own hard affinity rule.

**The point.** Read the field name literally: `requiredDuringScheduling` **`IgnoredDuringExecution`**. Required when landing; ignored once landed. Affinity is a landing rule, not a staying rule. (`RequiredDuringExecution` has been on the roadmap for years and still does not exist.)

Now restart and watch the same manifest fail:

```bash
kubectl rollout restart deployment/bees
kubectl get pods
kubectl describe pod -l app=bees | grep -A5 Events
```

```
0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector.
```

Put the marigold back:

```bash
kubectl label node garden-m02 flower=marigold --overwrite
```

### 4b — Soft affinity

```bash
kubectl apply -f manifests/04-bee-preferred-affinity.yaml
kubectl get pods -o wide
```

**Observe.** Most Pods land on `garden-m02` (marigold, weight 80), some on `garden-m03` (rose, weight 20), and some on plain `garden`, which matches neither. Nothing is Pending.

**The point.** `preferred` is a scoring input, not a filter. The scheduler ranks nodes and picks a winner, but it will always place the Pod somewhere rather than leave it Pending. That is a feature when you want best-effort placement, and a trap when you assumed it was a guarantee — because the failure mode is *"it worked, on the wrong machine."*

```bash
kubectl delete deployment bees
```

---

## Part 5 — Fogging the garden

Everything so far only affects Pods that are *landing*. `NoExecute` is the one effect that reaches in and removes Pods that are already running.

```bash
kubectl apply -f manifests/05-holding-breath.yaml
kubectl get pods -o wide -l app=holders
```

Three Pods, all pinned by hand to `garden-m02`, with three different lung capacities. Get K9s onto `:pods` filtered to them (`/holder`), or open a watch:

```bash
kubectl get pods -l app=holders -w
```

In a second terminal, fog the garden — and start a stopwatch:

```bash
kubectl taint nodes garden-m02 spray=fog:NoExecute
```

**Observe, in order:**

| Pod | Toleration | What happens |
|---|---|---|
| `holder-none` | none | evicted **immediately** |
| `holder-60` | `tolerationSeconds: 60` | evicted after about **60 seconds** |
| `holder-forever` | no `tolerationSeconds` | **never** evicted |

Now look at a toleration you never wrote:

```bash
kubectl get pod holder-forever -o yaml | grep -A12 tolerations
```

Every Pod in every cluster you will ever run gets two tolerations added automatically:

```
node.kubernetes.io/not-ready:NoExecute      tolerationSeconds: 300
node.kubernetes.io/unreachable:NoExecute    tolerationSeconds: 300
```

**The point.** This is the answer to a question you will be asked in production: *why did my Pods take five minutes to move after that node died?* Because the node controller taints a dead node `NoExecute`, and every Pod is holding its breath for 300 seconds before it lets go. It is tunable, and lowering it trades recovery speed against thrashing on a flaky network.

Clean up:

```bash
kubectl taint nodes garden-m02 spray=fog:NoExecute-
kubectl delete pod -l app=holders
```

---

## Part 6 — When insects care about other insects

Everything so far compared a Pod to a *node*. Anti-affinity compares a Pod to its *neighbours*.

```bash
kubectl apply -f manifests/06-anti-affinity.yaml
kubectl get pods -o wide -l app=spread-bees
```

**Observe.** Exactly one Pod per node. Not because of resources — because each Pod refuses to sit on a node that already holds a Pod labelled `app=spread-bees`, including its own siblings.

Now find the edge:

```bash
kubectl scale deployment spread-bees --replicas=4
kubectl get pods -o wide -l app=spread-bees
kubectl describe pod -l app=spread-bees | grep -A5 Events
```

```
0/3 nodes are available: 3 node(s) didn't match pod anti-affinity rules.
```

**The point.** Hard anti-affinity on `kubernetes.io/hostname` caps your replica count at the number of nodes. Three nodes means three replicas, forever, no matter what your HPA thinks. This is a real outage: an autoscaler that cannot scale, silently, because the fourth Pod never schedules.

`topologyKey` is the field that decides what *"the same garden"* even means:

| topologyKey | "Same garden" means | Protects you from |
|---|---|---|
| `kubernetes.io/hostname` | the same machine | one node dying |
| `topology.kubernetes.io/zone` | the same datacentre | one zone going dark (and costs cross-zone traffic) |
| `kubernetes.io/os` | **the entire cluster** | nothing useful — see Bug 5 |

```bash
kubectl delete deployment spread-bees
```

---

## Part 7 — The pattern you will actually deploy

Build a dedicated node pool properly. This is the shape all of the above was leading to.

```bash
# 1. the taint — keeps ordinary workloads OUT of the expensive pool
kubectl taint nodes garden-m03 dedicated=gpu:NoSchedule

# 2. the label — so the workload can find it
kubectl label node garden-m03 hardware=gpu

# 3. the workload — carries both a toleration AND an affinity
kubectl apply -f manifests/07-the-full-pattern.yaml
kubectl get pods -o wide -l app=ml-trainer
```

Both Pods on `garden-m03`. Now prove each lever is load-bearing by removing one at a time and predicting the outcome *before* you look:

| Remove | Prediction | What actually happens |
|---|---|---|
| the taint | | ordinary Pods drift onto your GPU node |
| the toleration | | `ml-trainer` goes Pending — it can't get past its own pool's spray |
| the affinity | | `ml-trainer` runs happily on a cheap node and nobody notices |

Fill in the middle column first. Then test the third row — it's the one worth the time.

---



## Cleanup

```bash
kubectl delete -f gauntlet/ --ignore-not-found
kubectl delete -f manifests/ --ignore-not-found

# or just burn the whole garden down
minikube delete -p garden
kubectl config use-context minikube
```

---



## The one line

**Taints repel and live on the node. Everything else is the Pod's own preference.**

If you can say where each object lives and which direction it points, you understand this topic.
