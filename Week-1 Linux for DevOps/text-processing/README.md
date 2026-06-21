# Text Processing Practice — the "Orbit" dataset

Five files describing one fictional SaaS company, **Orbit**, captured at the
same moment (around `2026-06-18T09:xx`). Because they describe the same system,
you can chase a question across files: see a `500` in the access log, find the
matching `ERROR` in the app log, then look up the broken service in the JSON.

| File | Format | Use it to practice |
|------|--------|--------------------|
| `users.csv` | CSV | `grep`, `cut`, `sort`, `uniq`, `awk`, and **why CSV ≠ "split on comma"** |
| `app.log` | app log | `grep`, `sed`, `awk` — levels, components, key=value fields |
| `nginx_access.log` | combined log | `awk` column work — status codes, IPs, bytes, methods |
| `services.json` | JSON | `jq` — nested objects, arrays, `select`, `add`, `group_by` |
| `config.yaml` | YAML | `yq` (mikefarah) — nested keys, lists, editing values |

## Schemas

**users.csv** — `id,name,email,role,country,signup_date,plan,active,monthly_spend`
Roles: `admin` / `user` / `viewer` (note one is capitalised `Admin`).
Plans: `free` / `pro` / `team` / `enterprise`. `active` is `true`/`false`.
⚠️ One row has a **comma inside a quoted name** — that row is your CSV trap.

**app.log** — `TIMESTAMP [LEVEL] component: message key=value ...`
Levels: `INFO WARN ERROR DEBUG`. Components: `auth api db cache worker billing`.
Watch for a burst of failed logins from one IP — a brute-force attempt.

**nginx_access.log** — Apache/nginx *combined* format. Whitespace-separated, so
`$1`=IP, `$6`=`"METHOD`, `$7`=path, `$9`=status, `$10`=bytes.

**services.json** — a cluster manifest: `cluster`, `region`, and a `services[]`
array. Each service has `name, image, replicas, port, healthy, env, resources,
tags[]`. Two services are unhealthy; one service is in `staging`.

**config.yaml** — app config with nested `database` (incl. a `replicas[]` list),
`cache`, a `services[]` list, and `feature_flags`.

➡️ Work through **`EXERCISES.md`**. Answers (with expected output) are in
**`SOLUTIONS.md`** — try each problem before peeking.
