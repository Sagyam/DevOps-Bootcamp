# Day 2 — Metrics

**Time:** 90 minutes
**You will finish with:** the same tea shop, now publishing numbers, scraped by Prometheus and drawn in Grafana.

---

## Where we left off

Yesterday you built a p95 latency chart out of nginx access logs. It worked. Go back and read that panel's description — it said the chart was expensive, and it was: Loki had to fetch and parse **every matching log line in the window** to compute one number.

At 5 requests per second on your laptop, who cares. At 5,000 requests per second across 40 services, that query is a small data-warehouse job that you want to run every 10 seconds on a dashboard. It does not work.

A metric solves this by throwing away the individual events on purpose.

| | Logs | Metrics |
|---|---|---|
| Stores | every event, in full | aggregates only |
| Cost of 1M requests | 1M lines | ~40 numbers |
| Answers | *which* request failed | *how many* failed, how fast |
| Retention | days | months, cheaply |

Neither replaces the other. Metrics tell you **something is wrong and how bad**. Logs tell you **which request**. Tomorrow, traces tell you **where in the code**.

---

## What changed since Day 1

Only these. Everything else is byte-identical, so `diff -r ../day1-logs .` is a genuinely useful thing to run.

**New files**
```
app/src/metrics.ts                 all four metric types, one example of each
app/src/metrics.middleware.ts      turns each request into two numbers
app/src/metrics.controller.ts      GET /metrics
prometheus/prometheus.yml          who to scrape, how often
grafana/dashboards/day2-metrics.json
```

**Modified**
```
app/src/shop.service.ts            business counters next to the existing logs
app/src/app.module.ts              registers the new middleware and controller
app/package.json                   + prom-client
nginx/nginx.conf                   + stub_status endpoint
docker-compose.yml                 + prometheus, + nginx-exporter
grafana/provisioning/datasources/  + Prometheus, now the default
```

---

## Start it

```bash
cd day2-metrics
docker compose up --build
```

| What | Where |
|---|---|
| Grafana → *Day 2 - Metrics* | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Raw metrics from the app | http://localhost:8080/metrics |
| Swagger | http://localhost:8080/docs |

Yesterday's *Day 1 - Logs* dashboard is still there. Loki is still running. Nothing was taken away.

---

## Part 1 — What a metric actually is (15 min)

Open **http://localhost:8080/metrics** in your browser. Read it. It is plain text and it is the whole protocol.

```
# HELP chiya_http_requests_total Total HTTP requests handled, by method, route and status code
# TYPE chiya_http_requests_total counter
chiya_http_requests_total{method="GET",route="/teas",status="200"} 4821
chiya_http_requests_total{method="GET",route="/teas/:id",status="404"} 137
chiya_http_requests_total{method="POST",route="/orders",status="201"} 902
```

That is it. Prometheus is a program that fetches this text every 5 seconds and remembers each number with a timestamp.

Now notice the direction of the arrow:

```
Day 1 logs:     app  →  stdout  →  alloy  →  loki        the app PUSHES
Day 2 metrics:  prometheus  →  app:3000/metrics          the scraper PULLS
```

Pull has a consequence that trips people up: because Prometheus opened the connection, **Prometheus** knows who it is talking to. It attaches `job` and `instance` labels itself. That is why `metrics.ts` deliberately does *not* set its own instance label — if it did, Prometheus would rename ours to `exported_instance` and you would lose twenty minutes to confusion. Read the comment at the top of that file.

### The four metric types

Open `app/src/metrics.ts`. It has one example of each type and a comment explaining when to reach for it.

- **Counter** — only goes up. `chiya_http_requests_total`. You never read its value; you read `rate()`.
- **Gauge** — goes up and down. `chiya_tea_stock`. A snapshot at scrape time.
- **Histogram** — counts observations into buckets. `chiya_http_request_duration_seconds`. This is where percentiles come from.
- **Summary** — computes percentiles in-process. We do **not** use one, and the comment explains why: you cannot average two replicas' percentiles, so summaries do not aggregate. Histograms do.

Two things worth staring at in that file:

**Why counters may never go down.** `rate()` is built to detect a drop as a process restart and handle it. That contract only works if a decrease can *only* mean a restart. Allow decrements and `rate()` becomes wrong.

**Why bucket edges are a real decision.** A histogram does not store your durations. It stores "how many were under 5ms, under 10ms, under 25ms…" and interpolates percentiles from those counts. If all your requests land between 50ms and 100ms and you have no bucket boundary in there, your p95 is a confident, straight-faced lie.

---

## Part 2 — Cardinality, and how people break their own monitoring (15 min)

This is the part to actually remember.

Prometheus stores **one time series per unique combination of label values**. In `metrics.middleware.ts`:

```ts
const route = (req as any).route?.path ?? 'unmatched';
```

`req.route.path` is the pattern — `/teas/:id`. `req.originalUrl` is the real URL — `/teas/4127`.

If we had used the URL:
- one series per tea id, forever
- they never expire; Prometheus keeps them for the whole retention period
- and anyone on the internet could create unlimited series just by hitting random URLs

That last one is a denial-of-service against your own monitoring, launched by a stranger with `curl`. The `?? 'unmatched'` fallback exists specifically to close it.

**The rule:** a label value must come from a small, fixed set you could write on a napkin. If you cannot list the possible values, it belongs in a log field, not a metric label.

Check `chiya_orders_total{outcome, tea}`: 4 outcomes × 5 teas = 20 series. Listable. Safe.

You will test this for real in exercise 4.3.

---

## Part 3 — Reading the dashboard (20 min)

Open Grafana → **Day 2 - Metrics**.

### The four numbers at the top

**Requests / sec**
```promql
sum(rate(chiya_http_requests_total[$__rate_interval]))
```
`rate()` computes per-second increase over the window. `sum()` collapses every label combination *and both replicas* into one number.

**Error rate**
```promql
100 * sum(rate(chiya_http_requests_total{status=~"5.."}[$__rate_interval]))
    / sum(rate(chiya_http_requests_total[$__rate_interval]))
```
A ratio of two rates. Note it is a *percentage of traffic*, not a count — 50 errors means something very different at 100 rps than at 10,000 rps.

**p95 latency**
```promql
histogram_quantile(0.95, sum by (le) (rate(chiya_http_request_duration_seconds_bucket[$__rate_interval])))
```
Read it inside out:
1. `rate(..._bucket[...])` — how fast each bucket is filling
2. `sum by (le)` — merge buckets across routes, statuses **and both replicas**, keeping only the bucket boundary
3. `histogram_quantile(0.95, ...)` — interpolate

Step 2 is the whole reason histograms beat summaries. You are combining raw bucket counts *before* computing the percentile. Averaging two pre-computed p95s, which is what a summary would force you to do, is mathematically meaningless.

**Orders / min** — a business number, next to the technical ones, costing the same. When revenue drops and every technical panel is green, you have found the incident nobody would have paged for.

### Compare with yesterday

Open the **Latency percentiles** panel, then open yesterday's log-derived version in the *Day 1 - Logs* dashboard. Set both to a 6-hour range.

Same shape. Wildly different load time. That is the entire argument, and now you have felt it rather than been told it.

### The Node.js row

All of it comes free from one line in `metrics.ts`:

```ts
client.collectDefaultMetrics({ register: registry });
```

**Event loop lag (p99)** is the one to learn. Node runs your JavaScript on a single thread. This metric measures how long a callback waited for its turn. If it rises, something is blocking that thread and *every* request slows down at once — not just the slow endpoint.

Remember this panel. Tomorrow we add deliberately slow code and you will watch it react.

**Heap used** should saw up and down — that is garbage collection. A sawtooth that stops sawing and only climbs is a memory leak.

### Monitoring the monitoring

**Scrape targets up** uses `up`, a metric Prometheus synthesises itself: 1 if the last scrape succeeded. You should see four lines — two API replicas, nginx-exporter, prometheus. Two API lines is your proof that DNS service discovery found both.

**Time series stored** (`prometheus_tsdb_head_series`) is the number that decides whether your monitoring survives. Note its current value. You are about to change it.

---

## Part 4 — Exercises (35 min)

### 4.1 — Learn PromQL by breaking it

Go to Prometheus at http://localhost:9090, **Graph** tab. Run these in order and explain each result before moving on:

```promql
chiya_http_requests_total
```
Every series, raw counter values. Notice you get ~12 lines and they only go up. Useless as-is.

```promql
rate(chiya_http_requests_total[1m])
```
Per-second rate. Now it means something.

```promql
sum(rate(chiya_http_requests_total[1m]))
```
One line.

```promql
sum by (route) (rate(chiya_http_requests_total[1m]))
```
One line per route. `by` keeps a label; everything not named is collapsed.

```promql
sum without (instance) (rate(chiya_http_requests_total[1m]))
```
The opposite: keep everything *except* `instance`. Often what you actually want, because it survives someone adding a new label later.

Now deliberately get it wrong:

```promql
rate(chiya_tea_stock[1m])
```
Why is this meaningless? What is the rule?

<details>
<summary>Answer</summary>

`rate()` is only defined for counters. `chiya_tea_stock` is a gauge — it goes down when tea is sold, and `rate()` interprets every decrease as a process restart. You get nonsense, silently, with no error. Prometheus will not stop you.

For gauges you want `delta()`, `deriv()`, or just the raw value.
</details>

### 4.2 — Find the slow route

```promql
histogram_quantile(0.95, sum by (le, route) (rate(chiya_http_request_duration_seconds_bucket[5m])))
```

Which route is slowest? Now answer this: **can this query tell you why?**

No. It tells you *where the time was spent by URL*, not *what the code was doing*. That gap is exactly what tomorrow is for.

### 4.3 — Blow up the cardinality (do this one)

Note the current value of **Time series stored** on the dashboard.

In `app/src/metrics.middleware.ts`, change:

```ts
const route = (req as any).route?.path ?? 'unmatched';
```
to
```ts
const route = req.originalUrl;   // DO NOT SHIP THIS
```

Rebuild and watch:

```bash
docker compose up -d --build api
```

Then, in Prometheus, watch:

```promql
prometheus_tsdb_head_series
```

and

```promql
count(count by (route) (chiya_http_requests_total))
```

The load generator requests random tea ids between 900 and 999, so you are manufacturing new series continuously.

Questions:
- How fast is the series count climbing?
- Remember the histogram has 11 buckets, and each bucket is its own series. How many series does **one new route value** actually create?
- If a stranger scripted `curl` against random URLs on a public endpoint, what happens?

<details>
<summary>The arithmetic</summary>

One new `route` value creates:
- 1 series in `chiya_http_requests_total`
- 11 bucket series + `_sum` + `_count` = 13 in the histogram

per method, per status code. So roughly 14 series per unique URL — and the histogram is the expensive part. This is why "just add a label, it is only one label" is such a dangerous sentence.
</details>

**Change it back and rebuild.** Note that the bad series do not disappear — they stay until the retention window (1h here) expires. Damage from a cardinality mistake outlives the fix.

### 4.4 — Watch a gauge lose data

`chiya_tea_stock` is a gauge, set when teas are listed and when orders are placed.

Set `PAYMENT_FAILURE_RATE: '0'` and `RPS: '40'` in `docker-compose.yml`, then `docker compose up -d`. Ilam Gold has 3 cups and restocks every 60 seconds, so it will hit zero and recover fast.

- Does the **Cups in stock** panel ever show Ilam Gold at 0?
- Does `chiya_orders_total{outcome="rejected_stock"}` miss the rejections?
- What does that tell you about when a gauge is the wrong tool?

<details>
<summary>Answer</summary>

The gauge is sampled every 5 seconds. A dip that heals between two scrapes is invisible — the data was never wrong, it just was never observed.

The counter cannot miss anything, because it records the *event*, not the *level*. When accuracy matters, count the event as well as gauging the level. "Queue depth" gauges hide exactly this way in production.
</details>

Put the settings back.

### 4.5 — Add a metric yourself

Yesterday's exercise 4.5 asked you to log the number of orders rejected since the last restock, and hinted the answer was really a metric.

It already exists: `chiya_orders_total{outcome="rejected_stock"}`. Write the PromQL that answers "how many rejections in the last hour":

<details>
<summary>Answer</summary>

```promql
sum(increase(chiya_orders_total{outcome="rejected_stock"}[1h]))
```

`increase()` is `rate()` × the window — the same calculation, expressed as a total rather than a per-second figure. Use `increase()` when a human will read the number and `rate()` when a graph will.
</details>

Now add a genuinely new one. In `metrics.ts` add a counter `chiya_restocks_total`, increment it in `restock()` in `shop.service.ts`, rebuild, and confirm it appears at `/metrics`.

---

## Checks for understanding

1. Metrics pull, logs push. Name one operational consequence of each direction.
2. Why must a counter never decrease?
3. Why is `route` the pattern `/teas/:id` and not the URL? Give the number of series each choice would produce.
4. Explain `sum by (le)` in the p95 query. Why is that ordering not optional?
5. When would a gauge silently mislead you?
6. Your histogram's largest bucket is 5 seconds and a request takes 8. What does p99 report? What should you do?
7. Yesterday you got p95 from logs. Today from metrics. Name one thing the log version can do that the metric version cannot.

---

## Clean up

```bash
docker compose down
```

---

## What we did not cover

- **Alerting rules.** Prometheus can evaluate a PromQL expression on a timer and fire to Alertmanager. Same query language you used today — the interesting part is routing, grouping and not paging people at 3am for a blip.
- **Recording rules.** Precompute an expensive query on a schedule and store the result as a new series. This is how you make a slow dashboard fast.
- **Exemplars.** A histogram bucket can carry a sample trace id, so you can click a latency spike and jump straight to a trace of a request that caused it. You will want this after tomorrow.
- **Remote write / Mimir.** Prometheus on one machine has a ceiling. Mimir is the "M" in LGTM and is where you go past it.
- **Native histograms.** A newer Prometheus feature that makes bucket choice largely automatic.

---

## Tomorrow

Today's dashboard can tell you `/teas/:id` has a p95 of 400ms. It cannot tell you whether that is the database, a slow loop, or a call to another service.

Tomorrow: the inside of a single request.
