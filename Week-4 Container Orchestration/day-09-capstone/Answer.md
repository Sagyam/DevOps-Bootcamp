# Answer 

---

## The night before

| # | Task | Why |
|---|------|-----|
| 1 | Push this repo to a public GitHub repo of your own and let **both** workflows go green | Students clone something known-good. If CI is broken at 09:30 you lose the morning. |
| 2 | Flip all **eight** GHCR packages to public (3 images + 5 charts) | Private-by-default is the single biggest time sink in this lab. |
| 3 | Run `./platform/bootstrap.sh` and the full stage-3 install yourself, timed | You will find exactly one broken thing. Better tonight. |
| 4 | Consider a pull-through cache registry on the classroom LAN | Best mitigation by far if you have 30 minutes to set one up. |
| 5 | Keep your own working cluster running on a spare machine | Your fallback demo when a student is 40 minutes behind. |

---

## Timetable

| Time | Block | Notes |
|---|---|---|
| 09:00 | Architecture on the whiteboard. No terminals. | 30 min. Draw the four namespaces and the three tiers. |
| 09:30 | Stage 1 — push, build, publish images | Reserve 10 min just for package visibility; walk the room |
| 11:00 | Break | |
| 11:15 | Stage 0 — bootstrap.sh, walk through what it did | Verify `kubectl top nodes` for **everyone** before moving on |
| 12:00 | Data layer + **Postgres failover demo** (§4.6) | The highlight of the day |
| 13:00 | Lunch | |
| 14:00 | Stage 2 — charts, chart CI, OCI push | |
| 15:30 | Break | |
| 15:45 | Stage 3 — install, then the dev → prod upgrade | Sit in k9s in silence for 30 seconds |
| 16:15 | Experiments: anti-affinity, taints, HPA, RBAC, rate limit | §4.1–4.5 |
| 17:15 | CRD flex (§5) | First thing to cut |
| 17:30 | CNCF landscape, live, on the projector | |

**Cut list, in order:** the tiny operator → the CRD section → 4.9/4.10 → the StatefulSet
scale demo (4.7) → 4.8. **Never cut** 4.6 (failover) or the `values-prod.yaml` upgrade.
Those two carry the day.

---

## Talking points that land

**On operators (§3.1).** The moment students see `kubectl get statefulset` in `chiya-data`
and find only Valkey there, ask: *"Three Postgres pods, three PVCs, automatic failover, and
no StatefulSet. Why?"* Let them sit in it. Then: StatefulSet's ordinal rolling update
restarts pods in order — but a database needs switchover *first*, then restart. The built-in
controller cannot express that. An operator can, because it knows what Postgres is.

**On the Secret copy (§3.2).** Ask why Kubernetes refuses to do this for them. The answer —
a Secret that crosses namespaces makes namespaces worthless as a boundary — is more valuable
than the workaround.

**On the Pending pods (§3.4 / 4.1).** Frame it as a *feature* before anyone calls it a bug.
"The scheduler is refusing to lie to you about your capacity." Have a student read the
`describe pod` Events aloud.

**On the rate limiter (§4.5).** Be honest about Traefik OSS having no cache. Naming the gap
and naming the alternatives (Kong, APISIX) teaches more than making a plugin work.

**On the CRD (§5).** The line that lands: *"We just extended the Kubernetes API. No code.
The API server stores it, validates it, versions it, and every tool you own already knows
how to display it. An operator is that plus a program in a loop."*

**Closing line, roughly.** "You wrote almost no YAML today and got HA Postgres,
autoscaling, TLS, rate limiting and zero-downtime deploys. Ten years ago that was a team.
You have not learned Kubernetes — you have learned enough to read the manual for anything
on that wall."

---

## Deliberate design choices, and why

| Choice | Reason |
|---|---|
| **CloudNativePG**, not Zalando/Crunchy/Percona | One `helm install`, one CR, working failover in under three minutes — and the no-StatefulSet teaching moment |
| **Valkey hand-written**, not a chart | Broadcom moved the Bitnami catalog behind a paid tier; versioned images went to an unmaintained legacy repo. Any lab built on `bitnami/*` rots. Also: 40 lines teaches `volumeClaimTemplates` properly. |
| **Traefik**, not NGINX/Kong/Envoy Gateway | Fewest moving parts, every feature is a small declarative `Middleware`, one values file |
| **Three languages** (static/Go/Node) | Reuses the multi-stage Docker module; proves Kubernetes does not care what is in the container |
| **No bundler on the frontend** | CI finishes in 15 seconds. Nobody debugs Vite today. |
| **Resource names = chart names** (not release-prefixed) | Predictable DNS. `orders-api` is always `orders-api`. Students can reason about it. |
| **`scaleDownWindow: 60`** (default is 300) | So the class actually witnesses a scale-down instead of walking away |
| **No `imageName` on the CNPG Cluster** | Let the operator pick the Postgres image it was tested against. One less thing to get wrong. |
| **No `go.sum` committed** | `go mod tidy` runs in the Dockerfile. One dependency, keeps the repo copy-paste friendly. |

---

## Version notes

- **CloudNativePG** — the 1.30 line is current. Recent releases fixed a critical
  metrics-exporter CVE and three bugs in the HA failover path, which is precisely the code
  path your headline demo exercises. Do not pin to something old.
- **Traefik v3** uses the `traefik.io/v1alpha1` API group. Anything on the internet using
  `traefik.containo.us` is v2-era and will not apply.
- **Helm ≥ 3.8** required for OCI registries; the workflows pin v3.16.3.
- **Bitnami** is not usable for free any more. Say it out loud — it is a live supply-chain
  lesson and pairs well with the Promtail EOL material from the observability module.

---

## Minikube-specific gotchas

**Storage on multi-node.** Minikube's default provisioner is `hostPath` and is not
multi-node aware. Everything with a PVC in this lab is pinned to the `tier=data` node via
`nodeSelector`, so the path is always on the same node and behaves. Do not let students
remove those nodeSelectors "to see what happens" — they will get silent data loss rather
than an interesting error.

**Node names** are `chiya`, `chiya-m02`, `chiya-m03`. If a student changes `PROFILE`, the
node names change with it and `bootstrap.sh` handles that, but hand-typed commands will not.

**The control-plane node is schedulable** in minikube (unlike kind), which is why Traefik
lands there without needing a toleration. The toleration in `traefik-values.yaml` is
harmless insurance.

**CNI flakiness.** If cross-node pod traffic fails — usually visible as the APIs being
unable to reach `chiya-db-rw` — recreate with `--cni=flannel`. This is the single most
likely infrastructure failure of the day.

**RAM.** 3 nodes × 2600 MB is ~7.8 GB. On an 8 GB laptop use `NODES=2 MEM=2200` and
`--set postgres.instances=2`. The taint demo still works with 2 nodes; the required
anti-affinity demo still works because you only have one app node.

---

## Answer key for the experiments

- **4.1** — 2 of 4 `orders-api` pods Pending. Event: `didn't match pod anti-affinity rules`.
- **4.2** — Event: `had untolerated taint {tier: data}`. With the toleration it lands on the data node.
- **4.3** — `kitchen-api` should reach 6–10 replicas under `loadtest.sh`, back to 2 within ~2 minutes of the load stopping.
- **4.4** — `kubectl auth can-i` returns `no`, then `yes`. The UI Fleet panel shows the 403 hint text.
- **4.5** — roughly the first 10–15 POSTs return 201, the rest 429 (average 5, burst 10).
- **4.6** — expect one or two non-200s during promotion, then steady 200s. `kubectl -n chiya-data get cluster` returns to `Cluster in healthy state`.
- **4.7** — `valkey-0/1/2` created in strict order, PVCs `data-valkey-0/1/2`, all three surviving `scale --replicas=1`.
- **4.8** — quota rejection appears in events as `exceeded quota: chiya-app-quota`.
- **5** — the `priceNpr: 2` object is rejected by the API server with a validation error naming `spec.priceNpr in body should be greater than or equal to 10`.
