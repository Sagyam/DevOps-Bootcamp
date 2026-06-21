# Exercises — Text Processing & Filtering

Try each one with the tool named. Reach for `man grep` / `man awk` / `jq --help`
freely. Don't peek at `SOLUTIONS.md` until you've got something working.
Difficulty rises within each part: ★ warm-up · ★★ real · ★★★ stretch.

---

## Part 1 — `grep`: find & filter (`app.log`, `nginx_access.log`, `users.csv`)

1. ★ How many `ERROR` lines are in `app.log`? (count, don't list)
2. ★ Show every line about a **failed login**.
3. ★★ Ops says "someone is hammering us." Show only the requests in
   `nginx_access.log` that returned **404**, then the ones that returned **5xx**.
4. ★★ List the **admins** in `users.csv` — and make sure you catch the row where
   the role is capitalised `Admin`.
5. ★★ Print each "account locked" line in `app.log` **together with the one line
   above it** (context), so you can see what led to the lock.
6. ★★★ Show only lines in `app.log` that contain an **IP address**, using a
   regex rather than matching a literal IP.

## Part 2 — `cut` / `sort` / `uniq`: columns & counting (`users.csv`, `nginx_access.log`)

7. ★ Print just the **email** column from `users.csv`.
8. ★★ List the **distinct countries**, sorted, with no duplicates.
9. ★★ Count how many users are on **each plan**, most-popular first.
10. ★★ In `nginx_access.log`, find the **top 3 IPs** by number of requests.
11. ★★★ **CSV TRAP:** redo #8 and #9 and look closely. A bogus `viewer` shows up
    among the countries, and a date string shows up among the plans — and `free`
    is undercounted. *Why?* Explain it, then produce the **correct** plan counts.
    (Hint: one tool that splits on commas is the wrong tool here.)

## Part 3 — `sed`: transform & redact (`app.log`, `config.yaml`)

12. ★ Print `app.log` with every **IP address replaced** by `x.x.x.x`.
13. ★★ From the `ERROR` lines only, print **just the message** — strip the
    timestamp, level, and `component:` prefix.
14. ★★ Turn the `new_billing` feature flag in `config.yaml` from `false` to `true`
    **in the output only** (don't touch the file). Change *only* that line.
15. ★★★ Mask the local part of every email in `users.csv` (e.g.
    `aarav@orbit.io` → `****@orbit.io`), leaving the domain intact.

## Part 4 — `awk`: compute (`users.csv`, `nginx_access.log`, `app.log`)

16. ★ Print each user's **name** and **plan** (two columns).
17. ★★ Sum the **total `monthly_spend`** across all users.
18. ★★ Compute the **average `monthly_spend` of active users** only.
19. ★★ In `nginx_access.log`, count requests **by HTTP status code**.
20. ★★ Sum the **total bytes** served (`$10`) in `nginx_access.log`.
21. ★★ Count requests **per HTTP method** (`GET`, `POST`, …). Mind the quote on `$6`.
22. ★★★ In `app.log`, count log lines **by level** (`INFO/WARN/ERROR/DEBUG`).

## Part 5 — `jq`: JSON (`services.json`)

23. ★ List all **service names**.
24. ★★ Names of every **unhealthy** service (`healthy == false`).
25. ★★ **Total replicas** across the whole cluster (one number).
26. ★★ Services with **more than 2 replicas** — print `name replicas`.
27. ★★ Names of services tagged **`public`**.
28. ★★★ Count services **grouped by `env`** (e.g. `prod 6`, `staging 1`).
29. ★★★ Find any service that is tagged **`critical`** **and** is **not healthy** —
    that's your page-someone-now list.

## Part 6 — `yq`: YAML (`config.yaml`)  *(mikefarah yq — the Go one)*

30. ★ Print the **database port**.
31. ★★ List the **names of every service**.
32. ★★ List the names of services where **`public: true`**.
33. ★★ List the **read-replica hosts** under `database.replicas`.
34. ★★ Sum the **replicas** across `services` (one number).
35. ★★★ Output the **whole config as JSON** (so you can pipe it into `jq`).

## Part 7 — Combine the tools (pipelines)

36. ★★ **Top 3 IPs hitting `/api`** in `nginx_access.log`.
37. ★★★ Which **`user_id`** appears in the most `ERROR` lines of `app.log`?
38. ★★★ **Incident drill:** a `500` appears in `nginx_access.log`. Find the
    request, then find the matching `ERROR` in `app.log` from the same minute,
    then identify the **unhealthy service** in `services.json` it points to.
