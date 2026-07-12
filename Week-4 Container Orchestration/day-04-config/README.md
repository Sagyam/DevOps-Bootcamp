# Day 4 — ConfigMaps & Secrets

**Time:** ~2 hours · **You will leave able to:** externalize configuration out of your image, inject it as environment variables, handle secrets (and understand their real security boundary), and diagnose a pod that won't start because of missing config.

> Cluster running? Good. No workload needed to start — we build it up today.

---

## Part 1 — The mental model

One image, every environment. You should **never** rebuild your container to change a setting. Configuration lives *outside* the image and gets injected at runtime:

- **ConfigMap** — non-secret key/value config (URLs, feature flags, UI settings).
- **Secret** — same shape, but base64-encoded at rest and gated by RBAC. For passwords, tokens, keys.

Both can be injected two ways: as **environment variables** (what we do today) or **mounted as files**. podinfo reads `PODINFO_UI_COLOR` / `PODINFO_UI_MESSAGE` from the environment, so our config changes will be *visible* in the browser.

---

## Part 2 — Guided lab: config as env vars (~30 min)

```bash
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment-with-config.yaml
kubectl port-forward deploy/podinfo 9898:9898   # open http://localhost:9898
```

The UI is now **purple** with a custom message — both came from the ConfigMap, not the image.

| Goal | In K9s | kubectl twin |
|---|---|---|
| View the ConfigMap | `:cm` → select → `x` (or `d`) | `kubectl get cm podinfo-config -o yaml` |
| View the Secret (decoded) | `:secret` → select → `x` decodes it | `kubectl get secret podinfo-secret -o yaml` |
| Confirm env inside the pod | `:pods` → pod → `s`, then `env \| grep -E 'PODINFO_UI\|API_TOKEN'` | `kubectl exec -it deploy/podinfo -- env \| grep API_TOKEN` |

**The security lesson:** in `:secret`, press `x`. The token decodes to plaintext instantly. **base64 is encoding, not encryption** — anyone with `get secret` permission reads it. What actually protects a Secret is (a) RBAC limiting who can read it and (b) encryption-at-rest on etcd. That's why Day 9's RBAC matters.

---

## Part 3 — Change config, roll it out (~20 min)

Edit the ConfigMap live and watch what happens:

```bash
kubectl edit configmap podinfo-config      # change ui-color to "#16a085", save
```

Refresh the browser. **The color doesn't change yet.** Why? Env vars are injected at pod *start* — a running pod won't pick up ConfigMap edits. You must restart the pods:

```bash
kubectl rollout restart deploy/podinfo
```

Now it's teal. This is a real gotcha people hit constantly — remember: *env-var config needs a rollout to take effect.*

---

## Part 4 — Challenge (~15 min)

1. Add a new key `ui-logo` to the ConfigMap and wire it into the deployment as `PODINFO_UI_LOGO`. Roll out and confirm it took.
   <details><summary>hint</summary>Add the key with <code>kubectl edit cm podinfo-config</code>, then add an <code>env</code> entry with a <code>configMapKeyRef</code> and <code>kubectl rollout restart</code>.</details>
2. Decode the secret **without K9s**, using only `kubectl` and `base64 -d`.
3. Who in your cluster can currently read that secret? (You'll answer this properly on Day 9.)

---

## Part 5 — Break-fix: the missing key (~25 min)

```bash
kubectl apply -f deployment-missing-key.yaml
```

The new pod never reaches Running. Diagnose from the cluster:

- In K9s `:pods`, what's the status of the new pod?
- Press `d` → Events. What is Kubernetes complaining it can't find?

<details>
<summary><b>What you should have found</b></summary>

Status is `CreateContainerConfigError`. The Events say the ConfigMap has no key `ui-colour` — the manifest asked for the British spelling, but the ConfigMap defines `ui-color`. Kubernetes can't assemble the container's environment, so it never even starts the app.

**Notice where it failed:** *before* your application code ran. A whole class of "my app won't boot" problems are actually missing/misnamed config keys, caught by Kubernetes at container-creation time. Fix the key to `ui-color`.

</details>

---

## Recap — checks for understanding

1. Why should you never rebuild an image just to change a config value?
2. Is a Kubernetes Secret encrypted? What actually protects it?
3. You edited a ConfigMap but the running app didn't change. Why, and what's the fix?
4. `CreateContainerConfigError` vs `ImagePullBackOff` (Day 1) — what does each tell you about *where* things broke?

---

## Cleanup

```bash
kubectl delete -f deployment-with-config.yaml -f configmap.yaml -f secret.yaml --ignore-not-found
```

**Tomorrow (Day 5):** config is ephemeral by design. But databases need data to *survive* a restart. Enter **PersistentVolumes**, **PVCs**, and **StatefulSets**.
