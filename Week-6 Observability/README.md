# The Chiya Shop — a three-day observability lab

You are going to run a small tea shop API and then spend three sessions learning to see inside it.

The application never changes in any interesting way. What changes is how much you can find out about it while it runs.

| Day | Pillar | The question it answers | Stack added |
|---|---|---|---|
| **1** | Logs | *Which request failed, and what happened during it?* | Loki, Alloy, Grafana |
| **2** | Metrics | *How many, how slow, how bad?* | Prometheus, nginx-exporter |
| **3** | Traces | *Where inside the code did the time go?* | Jaeger, OpenTelemetry |

Each day is a self-contained folder. Each is one `docker compose up`. Each has its own README with the lab, the exercises and the answers.

---

## Before the first session

You need **Docker** with the Compose plugin, and about **4 GB of free RAM** and **6 GB of disk**.

```bash
docker --version
docker compose version
```

The first `docker compose up --build` downloads images and compiles TypeScript — give it 5–10 minutes on a decent connection. After that, startups are seconds. Do the first build **before** class if you can:

```bash
cd day1-logs && docker compose build
```

Ports used: `8080` (the app), `3000` (Grafana), `9090` (Prometheus), `16686` (Jaeger), `3100` (Loki), `12345` (Alloy). Run **one day at a time** — they all use the same ports.

---

## The application

A tea shop. Five teas, one orders table, deliberately small — this lab is about telemetry, not domain modelling.

```
                      ┌──────────┐
   loadgen ──────────▶│  nginx   │  load balancer, JSON access logs,
                      │  :8080   │  generates the request id
                      └────┬─────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
      ┌───────────────┐         ┌───────────────┐
      │  api (NestJS) │         │  api (NestJS) │   two replicas
      └───────┬───────┘         └───────┬───────┘
              └────────────┬────────────┘
                           ▼
                     ┌───────────┐
                     │ postgres  │
                     └───────────┘
```

**Endpoints** (Swagger UI at http://localhost:8080/docs):

| Method | Path | Notes |
|---|---|---|
| GET | `/healthz` | touches nothing; used to prove a point on Day 3 |
| GET | `/teas` | the menu |
| GET | `/teas/:id` | 404s produce warn logs |
| GET | `/teas/:id/pairings` | **Day 3 only** — deliberately slow, three different ways |
| POST | `/orders` | 409 when out of stock, 503 from a flaky fake payment gateway |
| GET | `/orders` | recent orders |
| GET | `/metrics` | **Day 2 onward** — Prometheus scrape endpoint |

**Two replicas, always.** This is not showing off. With one container you would just run `docker logs` and never need any of this. Aggregating telemetry from more than one instance is the entire reason the stack exists.

**A load generator runs continuously.** Its traffic mix is deliberately imperfect — some 404s, some 409s, some 503s — because a dashboard that only ever shows green teaches you nothing.

---

## How to work through a day

1. `cd` into the day's folder and `docker compose up --build`.
2. Open that folder's `README.md` and follow it top to bottom.
3. **Read the source files it points you at.** Every file is commented, and the comments are the lesson, not decoration. The READMEs tell you which file to read and when.
4. Do the exercises. Several of them ask you to break something on purpose — those are the ones that stick.
5. `docker compose down` at the end.

The days are cumulative in understanding but independent to run. Day 2 still has all of Day 1's logging. Day 3 still has all of Day 2's metrics. All dashboards from previous days are loaded in later days.

**Day 2 and Day 3 are forks of the day before.** The diff *is* the lesson:

```bash
diff -r day1-logs day2-metrics
diff -r day2-metrics day3-traces
```

Each day's README opens with a "what changed" list so you know what to look at.

---

## Folder layout

```
day1-logs/
├── README.md                the lab
├── docker-compose.yml       the whole system, commented service by service
├── app/                     the NestJS application
│   ├── prisma/schema.prisma
│   ├── Dockerfile
│   └── src/                 nine files, all commented
├── nginx/nginx.conf         load balancer + JSON access logs
├── alloy/config.alloy       the log shipping pipeline
├── loadgen/generate.js      synthetic traffic, no dependencies
├── prometheus/              (day 2 onward)
└── grafana/
    ├── provisioning/        datasources + dashboard loader, as code
    └── dashboards/          the dashboards, as JSON in git
```

Nothing is configured by clicking. Every datasource and every dashboard is a file, which means the whole environment is reproducible and reviewable — which is itself one of the lessons.

---

## The one idea that connects all three days

A single shared identifier, written by the application into all three signals.

- nginx generates a request id and forwards it as `X-Request-Id`
- the app puts it on **every log line** for that request (Day 1)
- the app also puts the OpenTelemetry `trace_id` on every log line (Day 3)
- Grafana turns that `trace_id` into a **clickable link** into Jaeger

Loki has never heard of Jaeger. Prometheus has never heard of either. They are joined by one string that the application wrote in one place, and that is what makes three separate systems behave like one.

It costs about six lines of code. It is the highest-leverage thing in this entire lab.

---

## Ports and URLs, all days

| Service | URL | From |
|---|---|---|
| Application (via nginx) | http://localhost:8080 | Day 1 |
| Swagger UI | http://localhost:8080/docs | Day 1 |
| Grafana | http://localhost:3000 | Day 1 |
| Alloy pipeline UI | http://localhost:12345 | Day 1 |
| Loki API | http://localhost:3100 | Day 1 |
| Raw app metrics | http://localhost:8080/metrics | Day 2 |
| Prometheus | http://localhost:9090 | Day 2 |
| Jaeger | http://localhost:16686 | Day 3 |

Grafana has no login — anonymous admin is enabled. Do not copy that part into anything real.

---

## Troubleshooting

**Grafana shows "No data" everywhere.**
Give it a minute; the load generator waits for the API to pass a health check before it starts. Then check `docker compose ps` — every service except `migrate` should be running, and `migrate` should be `exited (0)`.

**Alloy is running but no logs reach Loki.**
Alloy filters containers by the compose project label. If you renamed the project in `docker-compose.yml`, update the filter in `alloy/config.alloy` to match.

**Only one API replica appears anywhere.**
Check the `resolver 127.0.0.11` line in `nginx/nginx.conf`. nginx resolves a plain upstream hostname once at startup, which pins it to one container — the variable in `proxy_pass` is what forces re-resolution.

**Port already in use.**
Another day is still running. `docker compose down` in that folder first.

**Everything is slow / the fan is loud.**
Lower `RPS` on the `loadgen` service. `1` is plenty for reading individual log lines.

**Start completely fresh.**
```bash
docker compose down -v && docker compose up --build
```

---

## Nothing here is production-ready

Said plainly, because the gap matters:

- **No persistence.** Loki, Prometheus and Jaeger all store data inside their containers. `docker compose down` erases everything.
- **No authentication.** Grafana is open, and Alloy has the Docker socket, which is equivalent to root on the host.
- **No retention policy.** Prometheus is capped at one hour so a laptop survives. Retention is the single biggest cost lever in a real deployment.
- **Single instances of everything.** One Loki, one Prometheus, one Jaeger. At scale these become Mimir, Tempo, and object storage.
- **100% trace sampling by default.** Fine for a lab. Ruinous in production, which is what Day 3 exercise 4.3 is about.

Each day's README ends with a "what we did not cover" section listing the real-world things that were left out and what to look up next.
