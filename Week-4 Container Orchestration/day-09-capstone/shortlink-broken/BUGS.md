# Instructor answer key — shortlink-broken

Eight planted bugs, one per prior day. Students should diagnose each from K9s
`describe`/Events/logs, not by reading manifests. Symptoms are separated by host
where possible (`shortlink.local` = frontend chain, `api.shortlink.local` = api chain).

| # | Day | File | Bug | Symptom | Fix |
|---|-----|------|-----|---------|-----|
| 1 | 1 | 40-frontend.yaml | image tag `nginx:1.27-alpine-typo` | frontend pods `ImagePullBackOff` | correct tag to `nginx:1.27-alpine` |
| 2 | 2 | 20-redis.yaml | Deployment selector `app=redis` ≠ template label `app=cache` | **apply is rejected** with `selector does not match template labels` | make the two match |
| 3 | 3 | 40-frontend.yaml | frontend Service selector `app=frontendx` | `shortlink.local` → 503; frontend Service has **no endpoints** | selector → `app=frontend` |
| 4 | 4 | 30-api.yaml | `configMapKeyRef` key `ui-colour` | api pods `CreateContainerConfigError` | key → `ui-color` |
| 5 | 5 | 10-postgres.yaml | `storageClassName: fast-ssd` | `postgres-0` Pending; its PVC Pending | remove the line (use default) or set `standard` |
| 6 | 6 | 30-api.yaml | liveness path `/health` | api pods `CrashLoopBackOff` (app is fine!) | path → `/healthz` |
| 7 | 8 | 50-ingress.yaml | api host → Service port `9999` | `api.shortlink.local` → 503 while api is healthy | port → `80` |
| 8 | 9 | 60-rbac-reporter.yaml | Role verbs `["get"]` only | `reporter` pod logs: pods is forbidden ... cannot **list** | add `list`, `watch` |

**Suggested order students discover them:** apply the folder → the redis apply error (#2)
is immediate → fix and re-apply → then work pod-by-pod in K9s. Bugs #4 and #6 both sit on
the api Deployment and surface in sequence (fix the config error, then the crash-loop appears).

**Grading:** weight *how* they diagnosed (did they `describe` and read Events/endpoints?)
over raw count. All 8 green = the app answers on both hosts and `reporter` logs a clean pod list.
