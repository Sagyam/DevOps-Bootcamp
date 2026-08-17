# Tiffin — architecture

An order service for office lunches. Small on purpose: the interesting part
is everything around the application, not the application.

```
                    Internet
                       │
                  [ Ingress ]  TLS via cert-manager, rate limited
                       │
              ┌────────▼────────┐
              │  tiffin (x3)    │  Node 22, non-root, read-only rootfs
              │  /healthz       │  liveness  — process only
              │  /readyz        │  readiness — checks Postgres
              │  /metrics       │  Prometheus scrape
              └────┬───────┬────┘
                   │       │
           ┌───────▼──┐  ┌─▼──────────────┐
           │ Postgres │  │ OTel Collector │──▶ Tempo (traces)
           │  (RDS)   │  └────────────────┘──▶ Loki  (logs)
           └────┬─────┘                     ──▶ Mimir (metrics)
                │
        ┌───────▼────────┐
        │ nightly CronJob│──▶ S3 (versioned, KMS, lifecycle)
        └────────────────┘
```

## Decisions worth knowing

**Liveness does not check the database.** If it did, one database blip would
make Kubernetes restart every healthy pod simultaneously, converting a
degraded service into a full outage. Liveness answers "is this process
wedged"; readiness answers "should this pod get traffic".

**No CPU limit, memory limit required.** CPU limits cause CFS throttling that
shows up as mysterious tail latency. Memory has no such graceful degradation —
without a limit one leak can evict every pod on the node.

**Secrets never enter git.** Terraform generates the password, writes it to
Secrets Manager, and External Secrets projects it into the cluster. No human
ever sees the value, so no human can leak it.

**CI does not run `kubectl`.** It updates the desired state in git; Argo CD
reconciles. Cluster credentials never leave the cluster, which removes the
single most dangerous secret from CI.

**An outage is the absence of data.** The `TiffinAbsent` and
`TiffinBackupMissing` alerts fire on things _not happening_. Systems that only
alert on bad events stay silent during the worst failures.
