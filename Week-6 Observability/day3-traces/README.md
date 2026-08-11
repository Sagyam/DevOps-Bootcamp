# Day 3 — Traces

**Time:** 90 minutes
**You will finish with:** the same tea shop, now emitting traces to Jaeger, and one log line that can take you to the exact function that was slow.

---

## Where we left off

Day 2 ended with a question it could not answer.

Your dashboard says `GET /teas/:id/pairings` has a p95 of 400ms. Now what? A metric is **one number per request**. You cannot decompose it after the fact. Was it the database? A slow supplier API? A loop somebody wrote badly? The metric has already thrown that information away — that is precisely how it stays cheap.

A trace keeps it. A trace is the **inside of one request**: a tree of timed operations, each with a parent, each with attributes.

| | Answers | Cost |
|---|---|---|
| Metrics | *how many, how slow* | ~40 numbers, any traffic level |
| Logs | *which request* | one line per event |
| Traces | *where the time went* | ~9 spans per request, each ~1KB |

Traces are the most expensive telemetry you will ever collect. That is why half of today is about **not collecting all of them**.

---

## Vocabulary (it is small)

- **span** — one timed operation: a name, a start, an end, some attributes
- **trace** — every span sharing one trace id, forming a tree
- **context** — the current trace id and span id, passed down implicitly so a span three functions deep knows who its parent is

That is genuinely all of it.

---

## What changed since Day 2

**New files**
```
app/src/tracing.ts                 the OTel SDK, the sampler, the curation
grafana/dashboards/day3-traces.json
```

**Modified**
```
app/src/logger.ts                  + traceFields(), reads the active span
app/src/request-logger.middleware.ts  + trace_id on the request child logger
app/src/shop.service.ts            + pairings(), the deliberately slow endpoint
app/src/shop.controller.ts         + GET /teas/:id/pairings
app/Dockerfile                     CMD now preloads tracing.js with -r
app/package.json                   + OpenTelemetry, + @prisma/instrumentation
docker-compose.yml                 + jaeger, + OTEL_* env vars
grafana/provisioning/datasources/  + Jaeger, + Loki derived field
loadgen/generate.js                + a small share of pairings traffic
```

`diff -r ../day2-metrics .` is worth two minutes.

---

## Start it

```bash
cd day3-traces
docker compose up --build
```

| What | Where |
|---|---|
| **Jaeger** | http://localhost:16686 |
| Grafana → *Day 3 - Traces and correlation* | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Swagger | http://localhost:8080/docs |

All three dashboards from all three days are loaded.

---

## Part 1 — Read a trace (20 min)

Go to **Jaeger** → Service: `chiya-api` → Operation: `GET /teas/:id/pairings` → **Find Traces**. Click the slowest one.

You are looking at a waterfall. Roughly nine bars:

```
GET /teas/:id/pairings ────────────────────────────────  220ms
  request handler - /teas/:id/pairings ────────────────  219ms
    ShopController.pairings ───────────────────────────  219ms
      pairings ────────────────────────────────────────  218ms
        shop.pairings ─────────────────────────────────  218ms
          shop.popularity_n_plus_1 ──                      15ms
          supplier.price_lookup      ─────────             120ms
          shop.blend_score                    ────         79ms
```

Now open `app/src/shop.service.ts` and find `pairings()`. Read it next to the waterfall. Three deliberate problems, and **each has a different shape** — learning to recognise these by eye is most of what reading traces is:

**1. `shop.popularity_n_plus_1`** — expand it. Underneath you will find a row of near-identical short Prisma spans. One query to list the teas, then one more query *per tea*. This is the N+1 problem, the most common performance bug in any ORM codebase, and it is **invisible in metrics**: every individual query is fast, only the endpoint is slow. In a trace it is unmistakable — a picket fence.

**2. `supplier.price_lookup`** — one long bar, 120ms, nothing underneath. We are **waiting** on something. The CPU is free the whole time; other requests are being served normally.

**3. `shop.blend_score`** — one long bar, and it is **blocking**. Node runs your JavaScript on a single thread. While this loop runs, nothing else in this process moves — not other requests, not timers, not the health check.

Bars 2 and 3 look identical in the trace. They are completely different problems. Part 3 shows you how to tell them apart.

### Where the spans came from

Two sources, and you should know which is which:

**Automatic.** `tracing.ts` calls `getNodeAutoInstrumentations()`. That one line patches `http`, Express, NestJS and Prisma, which is why you get a full request tree without a single line in your controllers.

**Manual.** The four `shop.*` and `supplier.*` spans are ours:

```ts
return tracer.startActiveSpan('shop.pairings', async (span) => {
  span.setAttribute('chiya.tea_id', teaId);
  ...
});
```

`startActiveSpan` does two things: creates the span, and makes it *current* for everything inside the callback. That is why the spans below it nest automatically instead of ending up as siblings.

Click `shop.blend_score` and look at **Tags**. `chiya.iterations` and `chiya.event_loop_blocked_ms` are there because we put them there. A span that only says "218ms" is half a clue; attributes are the *why*.

### Two mistakes that are worth making once

Read the bottom of `pairings()`:

```ts
} catch (err: any) {
  span.recordException(err);
  span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
  throw err;
} finally {
  span.end();
}
```

- **Forget `setStatus`** and a failed request looks *successful* in Jaeger. Green bar, no error, wrong.
- **Forget `end()`** and the span is never exported at all. No error anywhere — the trace just quietly lacks it.

Both are silent. Both are extremely common.

---

## Part 2 — Curating what you collect (15 min)

Open `app/src/tracing.ts` and read the `instrumentations` block.

Left at its defaults, auto-instrumentation produced **21 spans** for one request to this endpoint. Twelve of them were Express internals named `middleware - <anonymous>`. They are not wrong. They are noise — and noise costs you twice: once in storage, and again in the seconds a human spends scrolling past it during an incident.

So we turned things off:

| Disabled | Why |
|---|---|
| `instrumentation-fs` | a span for every file read; enormous volume, no value |
| `instrumentation-router` | duplicates Express with worse names |
| `instrumentation-net`, `-dns` | TCP/DNS spans; useful when you suspect the network, clutter otherwise |
| Express `MIDDLEWARE` layers | keeps the request-handler span, drops the twelve anonymous ones |
| `instrumentation-pino` | **deliberate** — see below |

Nine spans instead of twenty-one. The trace now reads like a story.

> **Try it:** comment out the `instrumentation-express` block, `docker compose up -d --build api`, and look at a trace. Do it once. Then put it back.

### The one we turned off on purpose

`@opentelemetry/instrumentation-pino` would silently inject `trace_id` into every log line for you. Convenient — and a black box.

We do it by hand in `logger.ts` instead:

```ts
export function traceFields() {
  const span = trace.getActiveSpan();
  if (!span) return {};
  const ctx = span.spanContext();
  return { trace_id: ctx.traceId, span_id: ctx.spanId };
}
```

`trace.getActiveSpan()` reads from OpenTelemetry's context propagation, which is built on the same `AsyncLocalStorage` you met on Day 1 for `requestId`. Same idea, one layer down. **In your own projects, turn the auto-instrumentation on and delete that function** — but now you know what it does.

Note the snake_case. `trace_id` and `span_id` are not a style slip; they are the conventional names every tracing backend and Grafana expect to find.

---

## Part 3 — Correlation: the actual payoff (15 min)

Open Grafana → **Day 3 - Traces and correlation**.

Work down the dashboard in the order it is laid out, because the order *is* the workflow:

1. **Metrics** — `p95 latency by route` shows one route is bad. Dead end, same as yesterday.
2. **Logs** — `Slow requests (over 200ms)` shows you which actual requests were slow.
3. **Expand any one of those lines.** There is a **TraceID** field with a button: *View trace in Jaeger*. Click it.

You just went from "the service is slow" to "here is the function" in three clicks and zero copy-pasting.

### How that link exists

There is no shared database and no join. There are two independent facts:

1. `app/src/logger.ts` writes `trace_id` onto every request-scoped log line.
2. `grafana/provisioning/datasources/datasources.yml` defines a **derived field**:

```yaml
derivedFields:
  - name: TraceID
    matcherRegex: '"trace_id":"(\w+)"'
    url: '$${__value.raw}'
    datasourceUid: jaeger
```

Grafana runs that regex over every rendered log line and turns the captured group into a link. Loki has never heard of Jaeger. Jaeger has never heard of Loki. They are joined by one string that the application wrote in one place.

That is the whole trick, and it is why "just put the trace id in your logs" is the single highest-value tracing advice there is.

### Blocking vs waiting — the panel to actually stare at

Look at **p95 of the FAST routes**.

`/healthz` returns a hardcoded object. It touches no database and does no work. It should be sub-millisecond, always.

It is not. It gets slower whenever `pairings` is busy — because `shop.blend_score` is holding the only JavaScript thread and every other request is stuck in the queue behind it.

`supplier.price_lookup` waits for 120ms and does **not** do this. Same duration in the trace, completely different blast radius.

That contrast is the reason "slow" is not one thing, and the reason you look at **Event loop lag (p99)** on the panel next to it.

---

## Part 4 — Exercises (35 min)

### 4.1 — Feel the difference between blocking and waiting

Watch **p95 of the FAST routes** and **Event loop lag (p99)** while you do each of these.

**A. More blocking.** In `docker-compose.yml` set `BLEND_ITERATIONS: '40000000'` (ten times more), then:
```bash
docker compose up -d api
```

**B. More waiting.** Put `BLEND_ITERATIONS` back to `4000000`. In `app/src/shop.service.ts`, change the supplier sleep from 120ms to 1200ms, then `docker compose up -d --build api`.

Answer:
- Which change moved event loop lag?
- Which change made `/healthz` slower?
- In Jaeger, both produce a longer bar. What in the trace would let you tell them apart *without* the metrics dashboard?

<details>
<summary>Answer</summary>

Only **A** moves event loop lag and only **A** slows `/healthz`. Waiting on I/O releases the thread; a `for` loop does not.

In the trace itself: look at whether *other traces overlapping in time* also got slower. Blocking damages its neighbours; waiting does not. Jaeger's trace comparison and the span's own attributes (`chiya.event_loop_blocked_ms`) are your evidence.

The real-world fix for CPU-bound work in Node is a worker thread or a queue — not a faster loop.
</details>

Put both settings back.

### 4.2 — Fix the N+1

`shop.popularity_n_plus_1` runs one query per tea. Replace the loop with a single `groupBy`:

```ts
const grouped = await this.prisma.order.groupBy({
  by: ['teaId'],
  _sum: { quantity: true },
});
```

Rebuild, hit the endpoint, open a new trace.

- How many Prisma spans before, and after?
- How much time did you save?
- Would the Day 2 dashboard have told you this was worth doing?

The last question is the point. The metric said "400ms". The trace said "six round trips to Postgres for data you could have got in one".

### 4.3 — Turn sampling down (do this one)

Read the sampling comment block at the top of `tracing.ts` first.

Set `TRACE_SAMPLE_RATIO: '0.1'` in `docker-compose.yml`, restart the API, wait two minutes, then go to Jaeger.

- Roughly what fraction of requests now have traces?
- **Now find the trace for a specific slow request.** Take a `trace_id` from the Grafana logs panel and paste it into Jaeger's search box. What happens, and how often?
- Some log lines will still have a `trace_id` whose trace does not exist in Jaeger. Explain that.

<details>
<summary>Answer</summary>

The trace id exists whether or not the trace was *kept* — sampling decides whether spans get exported, not whether a trace id is generated. So you get log lines pointing at traces that were never stored. Clicking the link gives you an empty Jaeger page.

This is the fundamental problem with head-based sampling: **the decision is made at the start of the request, before anyone knows it was going to be interesting.** The slow request a customer is complaining about is probably not in your 10%.

The production answer is **tail sampling**: buffer whole traces in a collector, decide *after* seeing how they ended, keep 100% of errors and slow traces plus a few percent of the boring ones. It needs a collector doing the buffering, which is beyond today, but it is what you should reach for in a real system.
</details>

Note also that the decision is derived from the trace id, not a coin flip — so every service in a distributed system computes the *same* answer and you never get half a trace. That is what `ParentBasedSampler` and `TraceIdRatioBasedSampler` are doing together.

Set it back to `1.0`.

### 4.4 — Make a span lie

In `pairings()`, comment out these two lines:

```ts
span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
span.recordException(err);
```

Rebuild, then force a failure:

```bash
curl http://localhost:8080/teas/9999/pairings
```

Find that trace in Jaeger. It looks fine. No error flag, no exception, nothing red — for a request that returned a 404.

Put them back. This is the most common manual-instrumentation bug there is, and it fails silently in the direction of "everything is fine", which is the worst possible direction.

### 4.5 — Instrument something yourself

Add a span around the `$transaction` block in `placeOrder()`. Give it a sensible name and at least two attributes.

Then answer: from the trace, can you tell how much of an order's time is the transaction versus everything else? Could the Day 2 dashboard have told you that?

---

## Part 5 — Alerting: turning a dashboard into an email

Everything so far waits for a human to look at a screen. Alerting is Grafana watching the same Prometheus queries for you and paging you when they cross a line.

### One-time setup

1. `cp .env.example .env` and fill in `RESEND_API_KEY` (Resend dashboard → API Keys). Leave `ALERT_FROM_ADDRESS` blank to send from `onboarding@resend.dev` — no domain verification needed, but Resend will only deliver to the address your Resend account was signed up with.
2. Open `grafana/provisioning/alerting/contact-points.yaml` and replace `CHANGE_ME@example.com` with that same address. (Not an env var — see the comment in that file for why.)
3. `docker compose up -d grafana`

Grafana → **Alerting → Contact points** should show `resend-email` as provisioned. **Alerting → Alert rules**, folder *Chiya Shop*, should show five rules — all green/normal, because none of them should fire under the default load.

### The five alerts

Each one is quiet at the settings this lab starts with, and each has an exact knob to turn — read the `description` field on the firing alert, or `grafana/provisioning/alerting/rules.yaml`, for the command.

| Alert | Watches | Turn this knob |
|---|---|---|
| High 5xx error rate | 5xx share of all traffic > 20% | `PAYMENT_FAILURE_RATE: '0.9'` on `api` |
| Pairings p95 latency high | p95 of `/teas/:id/pairings` > 800ms | `BLEND_ITERATIONS: '40000000'` on `api` (exercise 4.1.A) |
| Event loop lag high | `nodejs_eventloop_lag_p99_seconds` > 0.3s | same knob as above — proves it's *blocking*, not waiting |
| A replica is down | `up{job="chiya-api"}` for any instance | `docker kill $(docker compose ps -q api \| head -n1)` |
| Request rate spike | total req/s > 30 | `RPS: '60'` on `loadgen` |

Pick one, edit `docker-compose.yml`, `docker compose up -d <service>`, and watch the rule go from green to pending (the `for:` duration) to firing in the Grafana UI — then check the inbox. Put the setting back afterwards; nothing auto-reverts.

Worth pointing out to a class: the latency alert and the event-loop alert share one root cause (`BLEND_ITERATIONS`) and fire together, while the 1200ms-supplier-sleep variant from exercise 4.1.B moves latency but **not** event loop lag — the same blocking-vs-waiting distinction from Part 3, now visible as two different alerts instead of two panels.

---

## Checks for understanding

1. What does a trace tell you that a metric cannot, and vice versa?
2. Why must `tracing.ts` be preloaded with `node -r` rather than imported from `main.ts`?
3. Metrics deliberately do *not* set `service`/`instance`; traces deliberately *do*. Why the difference?
4. What does a row of identical short database spans mean, and why is it invisible in metrics?
5. Two spans are both 120ms. One is `await fetch()`, one is a `for` loop. Which harms other requests, and which panel proves it?
6. You forget `span.end()`. What breaks, and how would you notice?
7. Head sampling at 10%: a customer reports a slow request and gives you a trace id. Roughly what are your odds, and what would fix it?
8. Explain the log→trace link without using the word "database".

---

## Clean up

```bash
docker compose down
```

Jaeger stores traces in memory, so this erases them.

---

## What we did not cover

- **Tail sampling.** The answer to exercise 4.3. Needs an OpenTelemetry Collector between the app and Jaeger, buffering traces so the keep/drop decision can be made after the request finishes.
- **Distributed tracing across services.** We have one service, so the trace never crosses a process boundary. With two, the trace context travels in the `traceparent` HTTP header (W3C Trace Context) and auto-instrumentation handles it for you. Everything you learned today applies unchanged — the waterfall just has more colours.
- **Exemplars.** A Prometheus histogram bucket can carry a sample trace id, so you can click a spike on a latency graph and land in a trace of a request that caused it. Metrics → traces, in one click, the same way logs → traces works today.
- **Span metrics.** A collector can derive RED metrics *from* spans, so you get per-operation rate/error/duration without writing any `prom-client` code.
- **Tempo.** The T in LGTM. Swapping Jaeger for it is one environment variable, because the application only ever speaks OTLP — that portability is the whole reason OpenTelemetry exists.
- **Continuous profiling.** The fourth pillar. A trace says `shop.blend_score` took 79ms; a profiler says which *line* burned the CPU. That is Pyroscope, and it is the natural next thing to learn.

---

## The three days in one paragraph

Logs are events, kept in full, expensive at volume, and they tell you *which*. Metrics are aggregates, cheap at any volume, and they tell you *how many and how bad*. Traces are the inside of one request, the most expensive of the three, and they tell you *where*. None of them replaces another, and the thing that makes them worth more together than separately is a shared id written into all three — which cost you about six lines of code in `logger.ts`.
