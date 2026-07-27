# Day 7 — Helm: Packaging & Templating

**Time:** ~2.5 hours · **You will leave able to:** install/upgrade/rollback an app with Helm, read a chart's structure, template manifests with values, override config per environment, and debug a chart before it ever hits the cluster.

> You have `helm` installed (checked Day 0). Cluster running? Good.

---

## Part 1 — The mental model

All week you ran `kubectl apply -f` on individual files. That doesn't scale to a real app (frontend + api + redis + config + service + ingress…), across dev/staging/prod, with versioning. **Helm** is the package manager that fixes this: one **chart** = a templated, versioned, configurable bundle you install as a single named **release**.

```
shortlink-chart/
├── Chart.yaml          # name + version of the chart and app
├── values.yaml         # the DEFAULT knobs (everything the templates reference)
├── templates/          # manifests with {{ }} placeholders
│   ├── _helpers.tpl    # reusable named-template snippets (labels, names)
│   ├── deployment.yaml # the api (podinfo)
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── redis-*.yaml    # rendered only if redis.enabled
│   └── NOTES.txt       # the message printed after install
└── values-prod.yaml    # (kept at day root) overrides for "production"
```

At install time Helm merges your values into the templates and applies the result. Change an environment by changing *values*, not by editing manifests.

---

## Part 2 — Render before you install (~25 min)

The most important Helm habit: **look at what it will produce before touching the cluster.**

```bash
cd day-07-helm

helm lint ./shortlink-chart                       # static checks
helm template demo ./shortlink-chart | less       # render locally — no cluster involved
```

Read the rendered output. Find where `{{ .Values.ui.color }}` became a real hex value, and where the `component: api` / `component: redis` labels keep the two services from selecting each other's pods. Now render with redis **off** and confirm the redis manifests vanish entirely:

```bash
helm template demo ./shortlink-chart --set redis.enabled=false | grep -c redis   # -> 0
```

That's the `{{- if .Values.redis.enabled }}` guard doing its job.

---

## Part 3 — Install, upgrade, rollback (~35 min)

```bash
helm install shortlink ./shortlink-chart        # creates a release named "shortlink" (prints NOTES.txt)
helm list
kubectl get all -l app.kubernetes.io/instance=shortlink
```

| Goal | Command | What to notice |
|---|---|---|
| Reach the api | `kubectl port-forward svc/shortlink-shortlink 8080:80` | default blue UI |
| Change a value + upgrade | `helm upgrade shortlink ./shortlink-chart --set replicaCount=4` | rolls to 4 replicas |
| See release history | `helm history shortlink` | revision numbers climb |
| Roll back | `helm rollback shortlink 1` | back to revision 1's state |

Every `upgrade` is a new revision; `rollback` is one command. This is the payoff over raw `kubectl`.

---

## Part 4 — Environment overrides (~20 min)

Same chart, different environment — just feed a different values file:

```bash
helm upgrade shortlink ./shortlink-chart -f values-prod.yaml
```

Port-forward again: the UI is now **red** with the production message, 3 replicas, higher resource limits, and an extra `ENVIRONMENT=production` env var (from the `range .Values.extraEnv` loop in the template). You changed the whole deployment's shape without editing a single manifest.

---


## Part 6 — Break-fix: debug a chart (~20 min)

Charts fail at **render** time, before the cluster ever sees them — a different debugging surface than the rest of the week. Practice it:

```bash
# Introduce a typo on the CLI to force a values path that doesn't exist, and see how it renders:
helm template demo ./shortlink-chart --set image.tag= | grep 'image:'
```

Notice the image line renders with an empty tag (`stefanprodan/podinfo:`) — a bug you'd catch in `helm template`/`helm lint` output, **not** from a cluster error. The lesson: `helm template` and `helm lint` are your first line of defense; render and read before you install.

<details>
<summary><b>Debugging toolkit</b></summary>

- `helm template <name> ./chart` — render locally, read the YAML.
- `helm lint ./chart` — catch structural mistakes.
- `helm install ... --dry-run --debug` — render *and* validate against the live cluster's API without creating anything.
- `helm get manifest <release>` — see exactly what a live release applied.

</details>

---

## Recap — checks for understanding

1. What's the difference between a *chart* and a *release*?
2. Where do you change a setting for production — the templates or the values? Why does that matter?
3. What's the one command you run before every install to see what will actually be applied?
4. Why must the labels in a `.spec.selector` stay stable across chart versions?

---

## Cleanup

```bash
helm uninstall shortlink
```

**Tomorrow (Day 8):** everything so far has been reachable only via port-forward or NodePort. We put a real front door on the cluster — an **Ingress** with hostname routing and TLS — and take a first look at observability.
