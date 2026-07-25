# Day 1 — Logs

**Time:** 90 minutes
**You will finish with:** a running tea shop, its logs flowing into Loki, and a Grafana dashboard you can read.

---

## The problem we are solving

You have an application. It is running somewhere you cannot see. A customer says "the site is broken."

Without logs, you have exactly two moves: guess, or reproduce it yourself. Both are slow, and neither works when the problem happened at 3am and stopped by the time anyone looked.

A log is a note the program leaves for you about something that happened. Today is about writing notes that are actually useful, and putting them somewhere you can read them all at once.

---

## What is in this folder

```
day1-logs/
├── docker-compose.yml          the whole system, eight services
├── app/                        the NestJS application
│   ├── prisma/schema.prisma    two tables: Tea, Order
│   ├── Dockerfile
│   └── src/
│       ├── logger.ts                     <- read this first
│       ├── request-logger.middleware.ts   <- then this
│       ├── shop.service.ts                <- then this
│       ├── prisma.service.ts
│       ├── shop.controller.ts
│       ├── app.module.ts
│       ├── dto.ts
│       ├── main.ts
│       └── seed.ts
├── nginx/nginx.conf            load balancer, JSON access logs
├── alloy/config.alloy          the agent that ships logs to Loki
├── loadgen/generate.js         synthetic traffic
└── grafana/
    ├── provisioning/           datasources + dashboard loader
    └── dashboards/day1-logs.json
```

Every file has comments explaining why it looks the way it does. They are part of the lesson, not decoration.

---

## Start it

```bash
cd day1-logs
docker compose up --build
```

The first build takes a few minutes (it compiles TypeScript and downloads the Prisma engine). After that it is seconds.

Watch the startup order in your terminal. `postgres` comes up, `migrate` runs and exits, then two `api` containers start. That ordering is enforced by `depends_on` conditions in the compose file — go read them.

Once it is quiet, open these:

| What | Where |
|---|---|
| Swagger UI | http://localhost:8080/docs |
| Grafana → *Day 1 - Logs* | http://localhost:3000 |
| Alloy pipeline UI | http://localhost:12345 |
| The API itself | http://localhost:8080/teas |

Grafana needs no login. It will already have the dashboard loaded.

---

## Part 1 — What a log line looks like (15 min)

Look at raw output first. Dashboards hide things.

```bash
docker compose logs -f api
```

You should see lines like this (reformatted here for reading; on your screen it is one line):

```json
{
  "level": "info",
  "time": "2026-07-25T09:14:02.881Z",
  "service": "api",
  "instance": "3f2c9a1b4e77",
  "requestId": "8a1f...c4",
  "orderId": 412,
  "teaId": 1,
  "name": "Masala Chiya",
  "quantity": 2,
  "totalNpr": 80,
  "stockLeft": 176,
  "msg": "order placed"
}
```

Three things to notice, and they are the whole of today:

**1. It is JSON, not a sentence.**
`msg` is a short, *constant* string. Everything that varies lives in its own field. This is what lets you later ask "how many orders were placed" without writing a regular expression. If the message had been `"order 412 placed for 2 cups"`, every line would be unique and you would be back to substring searching.

**2. There is a `level`.**
`info` for things that happened, `warn` for things the system correctly refused, `error` for things that actually failed. Open `src/shop.service.ts` and find the three log calls in `placeOrder()`. Argue with the levels I picked. "Tea not found" is a `warn` — is that right?

**3. There is a `requestId`.**
Every line produced while handling one HTTP request carries the same id. Copy one from your terminal and run:

```bash
docker compose logs api | grep <paste-the-id>
```

You get the whole story of that one request, in order, even though the lines came from four different functions.

> **Where does that id come from?** nginx. Look at `nginx/nginx.conf` — it generates `$request_id` and forwards it as `X-Request-Id`. The app reuses it rather than making its own, which is why the nginx line and the app lines match. `src/request-logger.middleware.ts` is where the app picks it up.

### How the app carries the id around

Open `src/logger.ts`. The interesting part is `AsyncLocalStorage`.

The naive way to get a request id into a deep function is to pass a logger down through every function signature. That pollutes every method in the codebase with a parameter that has nothing to do with what the method does.

`AsyncLocalStorage` is a per-request box. The middleware calls `requestContext.run(store, ...)` once, and any code running inside that request — however deep, however many `await`s later — can call `log()` and get a logger that already knows the id.

---

## Part 2 — Logs from more than one place (15 min)

Run this:

```bash
docker compose logs --tail 5 api nginx postgres
```

Three formats. The API's JSON, nginx's JSON, and postgres's own text format that we do not control.

That is normal, and it is the reason a log *aggregator* exists. You need one place where all of them are searchable together, and you need the ones you *do* control to share a schema.

Notice `nginx/nginx.conf` sets `"level":"info"` and `"service":"nginx"` by hand, matching the field names pino uses. That was a choice. It means one Grafana query works across both.

### The path a log line takes

```
your code  →  stdout  →  Docker  →  Alloy  →  Loki  →  Grafana
```

The application never mentions Loki. It writes to stdout and stops caring. Everything after that is infrastructure's problem — which means you can replace Loki tomorrow without touching application code.

Open http://localhost:12345 and click **Graph**. Alloy draws the pipeline defined in `alloy/config.alloy` as boxes and arrows. Compare that picture to the file. Five stages: find containers, name them, read stdout, parse, ship.

### Labels vs fields — the one thing to remember about Loki

Open `alloy/config.alloy` and find `discovery.relabel`.

Loki indexes **labels**, not log content. Every unique combination of label values is a separate *stream*, with its own index entry and its own files.

- Small, fixed set of values → make it a label. `service` has four values. `level` has five. Good labels.
- Unbounded values → never a label. `requestId` is unique per request. Making it a label would create millions of streams and take the cluster down. This failure has a name: **cardinality explosion**, and it is the number one way people break Loki.

`requestId` is still perfectly searchable — it is just searched as *content* (`|= "abc123"`), not as an index lookup. Slightly slower, does not destroy anything.

---

## Part 3 — The dashboard (20 min)

Open Grafana → **Day 1 - Logs**.

Work through it top to bottom:

**Log lines / sec.** Volume. This is the number your log bill is based on.

**API log volume by level.** The most useful log chart there is. You are not reading lines here — you are reading *shape*. A sudden orange spike is a story, and you go looking for it before anyone files a ticket.

**nginx responses by status code.** Note the query:

```logql
sum by (status) (count_over_time({service="nginx"} | json | __error__="" [$__interval]))
```

- `{service="nginx"}` — stream selector, uses the index. Fast.
- `| json` — parse each line at query time, turning JSON fields into temporary labels.
- `| __error__=""` — drop lines that were not valid JSON.
- `count_over_time(...)` — count per time bucket.

Everything after the `{}` runs over the raw lines. That is why the stream selector should be as narrow as you can make it.

**Request duration from nginx logs.** p50, p95, p99, computed by unwrapping the `requestTime` field out of every matching log line.

This one is a setup for tomorrow. It works, and it is expensive: Loki has to fetch and parse *every log line in the window* to draw it. Change the time range to 24 hours and watch it get slow. Tomorrow you will draw the same chart from metrics, instantly, at any time range. That difference is the entire reason metrics exist as a separate thing.

**Log lines per replica.** Two bars, one per API container. Proof that nginx is actually balancing. This panel is why we run two replicas — with one container you would just use `docker logs` and never need any of this.

**One request, end to end.** Copy a `requestId` out of the "Warnings and errors" panel below, paste it in the **requestId** box at the top of the dashboard. You now see nginx's line and every application line for that single request, together, in order.

That panel is the payoff for everything in Part 1.

---

## Part 4 — Exercises (30 min)

### 4.1 — Turn the volume up

In `docker-compose.yml`, change `LOG_LEVEL` on the `api` service to `debug`, then:

```bash
docker compose up -d api
```

Watch **Log lines / sec** in Grafana.

You are now seeing every SQL statement Prisma runs, with parameters and duration, tagged with the requestId that caused it. Look at `src/prisma.service.ts` to see how that is wired.

Questions to answer:
- Roughly how many times did your log volume increase?
- At 10× the volume, what does that do to a 40 GB/day log bill?
- Find a request in the **All API logs** panel and follow it: HTTP in → SQL → business event → HTTP out.

Now think about the trade-off. This information is *always* useful when debugging and *almost never* useful otherwise. That is exactly what log levels are for: the code stays, the cost is a switch.

Put it back to `info` when you are done.

### 4.2 — Make errors happen on purpose

Set `PAYMENT_FAILURE_RATE: '0.4'` on the `api` service and restart it. Then:

- Watch the error stat climb.
- In the **Warnings and errors** panel, click a line to expand it. You get `gateway`, `reason`, `teaId` as separate fields — because we put them in the object, not in the sentence.
- Write a query that counts failures grouped by cause:

<details>
<summary>Answer</summary>

```logql
sum by (reason) (count_over_time({service="api", level="error"} | json | __error__="" [$__interval]))
```

This only works because `reason` was a field. If the code had written `"payment failed: upstream_timeout"` as a message, you would be writing regex right now.
</details>

Set it back to `0.04`.

### 4.3 — Trace a 409 across the whole system

The load generator regularly tries to buy more *Ilam Gold (limited)* than exists. Find one of those rejections and answer, using only Grafana:

1. Which API replica handled it?
2. How long did nginx say the request took?
3. How many cups were requested, and how many were available?
4. Did the customer's client see a 409 or a 500?

<details>
<summary>Hint</summary>

Start here, grab a `requestId` from the result, and paste it into the dashboard variable:

```logql
{service="api", level="warn"} |= `insufficient stock`
```
</details>

### 4.4 — Break the parsing (do this one, it is the best lesson here)

In `nginx/nginx.conf`, delete `escape=json` from the `log_format` line. Restart nginx:

```bash
docker compose restart nginx
```

Then make a request with a nasty user-agent:

```bash
curl -H 'User-Agent: he said "hello" \ then left' http://localhost:8080/teas
```

Look at the **nginx responses by status code** panel and at the raw nginx logs.

- What happened to that line?
- Why did the *panel* silently lose data rather than showing an error?
- What does `| __error__=""` in the query have to do with it?

This is how log pipelines fail in real life: not with an alarm, but by quietly dropping the records you needed most. Put `escape=json` back.

### 4.5 — Add a log line yourself

In `src/shop.service.ts`, the `restock()` method logs at `info`. Change it so that when the scarce tea is restocked it also logs how many orders were rejected since the last restock. You will need to count them — think about whether that belongs in a log line at all, or whether it is really a metric.

(Hold that thought. It is tomorrow's topic.)

---

## Checks for understanding

Answer these out loud before you close your laptop:

1. Why is `msg` a constant string with the variable parts in separate fields?
2. `requestId` is not a Loki label. Can you still search by it? What is the cost?
3. Where does `requestId` originate, and why not generate it in the application?
4. The API writes to stdout and knows nothing about Loki. Name one concrete benefit of that.
5. You run `{job="chiya"} |= "error"` over 7 days and it takes 40 seconds. Why? What would make it fast?
6. A 404 is logged at `warn`, not `error`. Defend that choice, then attack it.

---

## Clean up

```bash
docker compose down
```

Loki's storage lives inside its container, so this deletes today's logs. That is intentional — tomorrow starts clean.

---

## What we did not cover

- **Log rotation and retention.** Loki here keeps everything until you `down`. Real deployments set retention per stream and it is usually the biggest cost lever you have.
- **Sampling.** At high volume you do not keep every line. You keep all errors and 1% of successes.
- **Multi-line logs.** A Java stack trace is one event spread over 30 lines. Alloy has a `stage.multiline` for stitching them back together.
- **PII.** We redact a few header names in `logger.ts`. Real systems need a policy, not a list.

---

## Tomorrow

You will notice today that answering "how many requests per second, and how slow are they?" made Loki read every log line in the window. That does not scale.

Tomorrow: the same questions, answered from numbers instead of text.
