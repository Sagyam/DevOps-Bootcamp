# Day 8 — Ingress, TLS & Observability

**Time:** ~2.5 hours · **You will leave able to:** expose services through one HTTP front door with hostname routing, terminate TLS, use the core observability tools, and trace a broken request through the Ingress → Service → Endpoints chain.

> The ingress controller must be running: `kubectl get pods -n ingress-nginx` should show a `controller` pod Running. If not: `minikube addons enable ingress`, wait ~1 min.

---

## Part 1 — The mental model

NodePort (Day 3) gives every service its own weird high port. That doesn't scale. An **Ingress** is one entrypoint that routes by **hostname** (and/or path) to many services, and terminates **TLS** in one place.

```
                      ┌────────────── Ingress (nginx controller) ──────────────┐
  https://podinfo.local ─▶│ host: podinfo.local  ─▶ Service podinfo ─▶ pods    │
  https://whoami.local  ─▶│ host: whoami.local   ─▶ Service whoami  ─▶ pods    │
                      └── TLS terminated here using the web-tls Secret ─────────┘
```

An Ingress is just routing rules — it needs an **ingress controller** (nginx here) actually running to enforce them.

---

## Part 2 — Setup: backends + hostnames (~25 min)

```bash
kubectl apply -f backends.yaml       # podinfo + whoami, each with a Service
```

Point the two hostnames at your cluster. Get the IP:

```bash
minikube ip        # e.g. 192.168.49.2
```

Add both names to your hosts file, pointing at that IP:

```
192.168.49.2  podinfo.local whoami.local
```

<details>
<summary><b>OS notes — where the hosts file is and how to edit it</b></summary>

- **Linux / macOS:** `sudo nano /etc/hosts`, add the line, save.
- **Windows:** open Notepad **as Administrator**, then open `C:\Windows\System32\drivers\etc\hosts`, add the line, save.
- **macOS/Windows with the docker driver:** if `minikube ip` isn't directly reachable, run `minikube tunnel` in a separate terminal (leave it open) and use `127.0.0.1` in your hosts file instead.
- Test resolution: `ping podinfo.local` should show your minikube IP (Ctrl-C to stop).
- **`.local` + mDNS gotcha (mainly Linux, also possible on macOS):** `.local` is reserved for multicast DNS (Bonjour/Avahi). On Linux, if `/etc/nsswitch.conf`'s `hosts:` line has `mdns_minimal [NOTFOUND=return]` listed *before* `files`, lookups for `podinfo.local`/`whoami.local` get intercepted by mDNS first — since nothing replies, the query hangs until timeout and your `/etc/hosts` entry is never even checked. Symptom: `curl` hangs/times out instead of failing fast, and `getent hosts podinfo.local` returns nothing. Fix: reorder that line so `files` comes before `mdns_minimal`, e.g. `hosts: mymachines files mdns_minimal [NOTFOUND=return] resolve myhostname dns`. (macOS's Bonjour can theoretically do the same; Windows doesn't intercept `.local` this way by default.)

</details>

---

## Part 3 — Ingress with TLS (~35 min)

```bash
kubectl apply -f tls-secret.yaml     # throwaway self-signed cert for *.local
kubectl apply -f ingress.yaml
```

| Goal | In K9s | kubectl twin |
|---|---|---|
| See the Ingress + its hosts | `:ing` → `d` | `kubectl describe ingress web` |
| Confirm it got an address | `:ing` (ADDRESS column populated) | `kubectl get ingress web` |
| Reach app #1 | — | `curl -k https://podinfo.local` |
| Reach app #2 (same IP!) | — | `curl -k https://whoami.local` |

Both hostnames hit the **same** IP and the Ingress routes by `Host:` header. `whoami` echoes the request so you can see exactly what arrived. The `-k` skips cert verification because our cert is self-signed — in a browser you'll get a warning you can click through. (Real clusters use cert-manager + Let's Encrypt for trusted certs.)

---

## Part 4 — Observability tour (~25 min)

You've used these all week; here they are as a named toolkit.

| Question | In K9s | kubectl |
|---|---|---|
| What's happening right now, cluster-wide? | `:events` | `kubectl get events -A --sort-by=.lastTimestamp` |
| Why is *this* pod unhappy? | pod → `d` (Events at bottom) | `kubectl describe pod <p>` |
| What is the app logging? | pod → `l` (`s` to toggle since/wrap) | `kubectl logs <p> -f` |
| Who's eating CPU/memory? | `:pu` / `:no` | `kubectl top pods` / `kubectl top nodes` |
| Full visual dashboard | — | `minikube dashboard` |

The muscle to build: **describe/Events for *why*, logs for *what the app said*, top for *resource pressure*.** Ninety percent of real debugging is those three.

---

## Part 5 — Challenge (~15 min)

1. Add a **path-based** rule so `podinfo.local/version` still reaches podinfo (hint: it already routes `/` — inspect what `pathType: Prefix` matches).
2. Using `whoami.local`, prove which backend pod served your request and what headers the Ingress added (`X-Forwarded-*`).
3. From `kubectl describe ingress web`, identify which Secret provides the TLS cert and which hosts it covers.

---

## Part 6 — Break-fix: 503 from the front door (~25 min)

```bash
kubectl apply -f ingress-broken.yaml     # same Ingress name — replaces the good one
curl -k https://podinfo.local            # 503 Service Temporarily Unavailable
```

The pods are healthy, the Service is fine — but the front door returns 503. Trace the chain:

- `kubectl describe ingress web` — what backend/port is `podinfo.local` pointing at?
- `kubectl get svc podinfo` — what port does the Service actually expose?

<details>
<summary><b>What you should have found</b></summary>

The Ingress routes `podinfo.local` to the `podinfo` Service on port **9999**, but the Service only listens on **80**. The controller has no valid backend, so it returns 503 — even though every pod is healthy. The lesson: a 503 at the Ingress is usually a **routing mismatch** (wrong service name or port), so walk the chain **Ingress → Service → Endpoints → Pod** one hop at a time. Fix the port to `80`.

</details>

---

## Recap — checks for understanding

1. What's the difference between an *Ingress* and an *ingress controller*? Which one does the actual work?
2. How does one IP serve both `podinfo.local` and `whoami.local`?
3. Where is TLS terminated, and where does the cert live?
4. You get a 503 from the Ingress but all pods are Running. What chain do you walk, and in what order?

---

## Cleanup

```bash
kubectl delete -f ingress.yaml -f tls-secret.yaml -f backends.yaml --ignore-not-found
# (optional) remove the podinfo.local/whoami.local lines from your hosts file
```

**Tomorrow (Day 9):** everything comes together. You deploy the full **ShortLink** stack — frontend, api, Postgres, Redis, ingress — lock it down with **RBAC**, then fix a deliberately sabotaged copy with eight bugs, one from every day this week.
