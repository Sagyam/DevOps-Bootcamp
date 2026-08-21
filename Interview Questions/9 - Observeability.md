## Observability

### 1. What is observability, and how is it different from monitoring?

- Monitoring: you decide in advance what to watch (CPU, disk, "is it up?"), build dashboards, and set alerts. It answers known questions.
- Observability: your system produces enough data (logs, metrics, traces) that you can ask new questions when something unexpected breaks.
- Short version: monitoring tells you something is wrong. Observability helps you find out why.
- You need both. Monitoring is one part of observability.

### 2. What are the three pillars of observability, and when do you use each?

- Metrics: numbers over time (request rate, error %, CPU). Cheap to store, easy to alert on, good for trends. Bad for detail about one request.
- Logs: text records of events ("user 42 payment failed: card declined"). Great for detail and debugging. Expensive at volume, hard to alert on.
- Traces: follow one request across many services with timing for each step. Best for "where is it slow?" in microservices.
- Rule of thumb: alert on metrics, debug with logs and traces.

### 3. What are the four golden signals?

- Latency: how long requests take. Track p95/p99 (the time 95% or 99% of requests finish within), not just the average.
- Traffic: how much demand (requests per second).
- Errors: how many requests fail (5xx server errors).
- Saturation: how "full" the system is (CPU, memory, DB connections, queue depth).
- From Google's SRE book. A good starting dashboard for any service.
- Related: RED (Rate, Errors, Duration) for services, USE (Utilization, Saturation, Errors) for resources like disks and CPUs.

### 4. How does Prometheus collect metrics?

- Pull model: Prometheus scrapes an HTTP `/metrics` endpoint on each target every few seconds.
- Targets are found via service discovery. In Kubernetes it finds pods automatically.
- Data is stored as time series: metric name + labels + value over time. Queried with PromQL. Alertmanager handles alerts.
- Metric types: counter (only goes up, e.g. total requests), gauge (goes up and down, e.g. memory), histogram (buckets, e.g. request duration).
- Watch out for cardinality: every unique label combination is a new time series. Never use user IDs or request IDs as labels. Put those in logs or traces instead.
- Short-lived jobs that die before a scrape use the Pushgateway.

### 5. What is distributed tracing?

- One user request may touch 5 services. A trace follows that request from start to end.
- Each step is a span (name, start time, duration, parent). Spans are linked by a trace ID passed along in HTTP headers.
- Lets you see exactly which service or database call made the request slow.
- Tools: OpenTelemetry to create the data, Jaeger or Grafana Tempo to store and view it.
- In production you usually sample (keep 1–10% of traces) to control cost, but keep all error traces.

### 6. What is OpenTelemetry (OTel)?

- An open standard and set of libraries for producing logs, metrics, and traces in one consistent format.
- Instrument your app once, then send the data anywhere: Jaeger, Tempo, Prometheus, Datadog, etc. No vendor lock-in.
- Main parts: SDKs (in your code), auto-instrumentation (zero-code for common frameworks), and the Collector (receives, processes, and exports data).
- Run by the CNCF (the same foundation behind Kubernetes). Most vendors accept OTel data, so it is the safe default.

### 7. What is structured logging and why does it matter?

- Write logs as JSON or key=value instead of free-form sentences.
- `{"level":"error","service":"payment","order_id":123,"msg":"card declined"}` instead of `Error: card declined for order 123`.
- Machines can filter and search by field. "All errors from payment service in the last 10 min" becomes one query in Loki.
- Always include a request ID or trace ID so you can jump from a log line to the full trace.
- Use log levels properly (debug, info, warn, error) and never log passwords, tokens, or card numbers.

### 8. What are SLIs, SLOs, and SLAs?

- SLI: a measurement. "Percentage of requests that succeed in under 300 ms."
- SLO: your internal target for that measurement. "99.9% over 30 days."
- SLA: a contract with a customer, usually with money attached if you miss it. Looser than the SLO.
- Error budget: the gap between 100% and your SLO. At 99.9%, you may fail about 43 minutes per month. If the budget is healthy, ship faster. If it is burned, slow down and fix reliability.

### 9. What makes a good alert?

- Actionable: a human needs to do something right now. If nothing needs doing, it should be a dashboard or a ticket, not a page.
- Based on symptoms users feel (error rate, latency, SLO burn), not causes (CPU at 80%). High CPU with happy users is not an emergency.
- Has a runbook: what to check, what to do.
- Not noisy: too many alerts → people ignore them → the real one gets missed. This is alert fatigue.
- Review alerts regularly. Delete the ones that never led to action.

### 10. Users say "the site is slow." Walk me through how you investigate.

- Confirm and scope: everyone or some users? One page or all? When did it start?
- Check the golden signals dashboard. Which one changed, and when? Line that up with recent deploys or config changes. Most incidents follow a change.
- Open a slow trace. Find the span that takes the time: app code, a database query, an external API?
- Look at logs for that service around that time. Filter by trace ID.
- Check saturation: CPU, memory, DB connections, queue depth, disk.
- Fix or roll back. Then write a short blameless post-mortem (what happened, how to prevent it, no finger-pointing).