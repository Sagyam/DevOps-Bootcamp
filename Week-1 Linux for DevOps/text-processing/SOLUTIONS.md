# Solutions (Instructor Key)

Every command below was run against the shipped data files; the **expected
output** shown is the real result. Many problems have more than one right
answer — these are clean, idiomatic ones.

> `awk` solutions use only POSIX features, so they work in both **mawk** and
> **gawk**. The one place that needs GNU awk (`FPAT`, #11) is flagged.

---

## Part 1 — grep

**1.** `grep -c ERROR app.log` → `10`

**2.** `grep "login failed" app.log` → 3 lines, all from `ip=198.51.100.9`, `user_id=1099`.

**3.** `grep -E '" 404 ' nginx_access.log` → `4` lines.  `grep -E '" 5[0-9]{2} ' nginx_access.log` → `3` lines (two `500`s plus none else; all are 500).

**4.** `grep -i admin users.csv` → 4 rows (`admin` ×3 + `Admin` ×1). The `-i` is the point — without it you miss Karan Mehta.

**5.** `grep -B1 "account locked" app.log` → shows the `[WARN] auth: account locked` line preceded by the third `login failed` line.

**6.** `grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' app.log` → all lines carrying an `ip=` or `host=` address.

## Part 2 — cut / sort / uniq

**7.** `cut -d, -f3 users.csv` (the trap row 1009 returns `Sushma"` — see #11).

**8.** `cut -d, -f5 users.csv | tail -n +2 | sort -u`
→ `AE BR CN DE FR GB IN JP NG NP US` … **plus a stray `viewer`** (the bug).

**9.** `cut -d, -f7 users.csv | tail -n +2 | sort | uniq -c | sort -rn`
→ `pro 6 · team 5 · free 4 · enterprise 4` … **plus a stray `2025-04-15` ×1** (the bug).

**10.** `cut -d' ' -f1 nginx_access.log | sort | uniq -c | sort -rn | head -3`
→ `7 198.51.100.9` · `7 10.2.4.18` · `5 203.0.113.44`

**11. (the CSV trap).** Row `1009` is `1009,"Rai, Sushma",...`. The comma **inside
the quoted name** makes `cut`/`-F,` see an *extra* field, so every column after
the name is shifted by one **on that row only**. That's why `viewer` (its real
role) lands in the country column and the signup date lands in the plan column,
and why `free` is undercounted. Lesson: **a CSV is not "text split on commas."**
Use a CSV-aware parser:

```bash
# portable: python's csv module respects quotes
python3 -c "import csv,collections; r=csv.reader(open('users.csv')); next(r); \
c=collections.Counter(row[6] for row in r); \
[print(f'{n:>3} {p}') for p,n in c.most_common()]"
# -> pro 6 · free 5 · team 5 · enterprise 4   (correct!)

# GNU awk only (gawk), using FPAT to honour quotes:
gawk -v FPAT='([^,]*)|("[^"]*")' 'NR>1{print $7}' users.csv | sort | uniq -c
```

## Part 3 — sed

**12.** `sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/x.x.x.x/g' app.log`
→ e.g. `... login succeeded user_id=1001 ip=x.x.x.x`

**13.** `grep ERROR app.log | sed -E 's/^.*\] [a-z]+: //'`
→ `query timeout after 5000ms query_id=Q-8841 user_id=1007`, etc. (timestamp/level/component stripped).

**14.** `sed '/new_billing/s/false/true/' config.yaml | grep new_billing`
→ `  new_billing: true`  (address `/new_billing/` limits the substitution to that line).

**15.** `sed -E 's/[a-z.]+@/****@/' users.csv`
→ `1001,Aarav Sharma,****@orbit.io,admin,...`

## Part 4 — awk

**16.** `awk -F, 'NR>1{print $2, $7}' users.csv` (row 1009 shifts — same CSV caveat as #11).

**17.** `awk -F, 'NR>1{s+=$9} END{print s}' users.csv` → `2665`

**18.** `awk -F, 'NR>1 && $8=="true"{s+=$9;n++} END{printf "%.2f\n", s/n}' users.csv` → `162.94`

**19.** `awk '{c[$9]++} END{for(s in c) print c[s], s}' nginx_access.log | sort -rn`
→ `200:14 · 404:4 · 500:3 · 401:3 · 403:2 · 301:1 · 204:1 · 202:1 · 201:1`

**20.** `awk '{s+=$10} END{print s}' nginx_access.log` → `309914`

**21.** `awk '{m=$6; gsub(/"/,"",m); c[m]++} END{for(k in c) print c[k], k}' nginx_access.log`
→ `GET 21 · POST 7 · PUT 1 · DELETE 1`

**22.** `awk '{print $2}' app.log | sort | uniq -c`
→ `[DEBUG] 3 · [ERROR] 10 · [INFO] 11 · [WARN] 6`

## Part 5 — jq (services.json)

**23.** `jq -r '.services[].name' services.json` → api, auth, worker, billing, cache, dashboard, analytics

**24.** `jq -r '.services[] | select(.healthy==false) | .name' services.json` → `billing`, `cache`

**25.** `jq '[.services[].replicas] | add' services.json` → `18`

**26.** `jq -r '.services[] | select(.replicas>2) | "\(.name) \(.replicas)"' services.json`
→ `api 4` · `auth 3` · `worker 6`

**27.** `jq -r '.services[] | select(.tags | index("public")) | .name' services.json`
→ `api`, `auth`, `dashboard`

**28.** `jq -r '.services | group_by(.env)[] | "\(.[0].env) \(length)"' services.json`
→ `prod 6` · `staging 1`

**29.** `jq -r '.services[] | select((.tags|index("critical")) and .healthy==false) | .name' services.json`
→ `billing`

## Part 6 — yq (config.yaml, mikefarah)

**30.** `yq '.database.port' config.yaml` → `5432`

**31.** `yq '.services[].name' config.yaml` → `api`, `auth`, `worker`, `billing`

**32.** `yq '.services[] | select(.public == true) | .name' config.yaml` → `api`, `auth`

**33.** `yq '.database.replicas[].host' config.yaml`
→ `db-ro-1.internal.orbit.io`, `db-ro-2.internal.orbit.io`

**34.** `yq '[.services[].replicas] | add' config.yaml` → `15`

**35.** `yq -o=json config.yaml`  (pipe into jq: `yq -o=json config.yaml | jq '.feature_flags'`)

## Part 7 — pipelines

**36.** `grep '/api' nginx_access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -3`
→ `5 203.0.113.44` · `5 10.2.4.18` · `4 198.51.100.9`

**37.** `grep ERROR app.log | grep -oE 'user_id=[0-9]+' | sort | uniq -c | sort -rn | head -1`
→ `3 user_id=1099`  (the brute-force victim/attacker).

**38. (incident drill).** A clean trace:
```bash
grep -E '" 500 ' nginx_access.log        # find the failed requests
grep '09:23' app.log | grep ERROR        # same-window app errors
jq -r '.services[]|select(.healthy==false)|"\(.name) port=\(.port)"' services.json
```
The app log shows `[ERROR] cache: connection refused host=10.0.0.5 port=6379`, and
`services.json` lists `cache` as `healthy:false` on `port 6379` — **the ports match**.
The 500s in the access log are the user-visible symptom; the unhealthy `cache`
(and `billing`) service is the root cause. That cross-file hop — symptom → log →
manifest — is exactly the muscle this dataset is built to train.
