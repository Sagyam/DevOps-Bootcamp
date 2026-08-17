# The Tiffin Audit Lab

A comprehensive, hands-on DevOps and Platform Engineering audit lab comparing an anti-pattern legacy system against a production-grade reference architecture.

---

## The Story

> **"Bikash built this in six weeks, shipped it, and left for a job in Australia. Nobody else has ever opened the repository. You are the platform team that just inherited it. Leadership wants to know: can we keep running this?"**

At first glance, the system seems to work: you can spin up the containers, view the menu, and place orders. But under the hood lies a landmine of **83 critical defects** spanning security vulnerabilities, supply chain risks, container escapes, deployment race conditions, missing observability, and **four independent guarantees of total, unrecoverable data loss**.

This project provides two complete implementations of the **Tiffin** office lunch ordering service:

1. **`tiffin-nightmare/`**: The legacy repository left behind by Bikash. It runs, but violates almost every principle of modern platform engineering and security.
2. **`tiffin-pristine/`**: The clean reference implementation demonstrating how the same system should be built, packaged, secured, deployed, observed, and backed up in production.

---

## Lab Architecture & Coverage

| Domain | Nightmare Anti-Patterns | Pristine Production Standard |
|---|---|---|
| **Repository Hygiene & Supply Chain** | Committed `.env` secrets, missing lockfile, broad gitignore | `.env.example`, verified `package-lock.json`, strict `.gitignore`, `.editorconfig` |
| **Application & Code Security** | SQL injection, wildcard CORS with credentials, PII logging, hardcoded DB strings | Zod input validation, parameterized queries, structured pino logging with PII redaction |
| **Docker & Containers** | Root container, single-stage, bloated tools, baked-in secrets, shell-form CMD | Multi-stage build, unprivileged `node` user, `dumb-init` PID 1, pinned digests, HEALTHCHECK |
| **CI / CD Pipelines** | Arbitrary code execution via `pull_request_target`, unpinned master actions, static AWS secrets | 4 automated gates (lint, test, security, build), SHA-pinned actions, OIDC authentication |
| **Kubernetes** | `hostNetwork: true`, `hostPath: /` escape, `privileged: true`, bare Pod, `emptyDir` | PSA restricted, non-root, read-only rootfs, probes, NetworkPolicy, PDB, StatefulSet with PVC |
| **Infrastructure as Code** | Hardcoded AWS credentials, public RDS, no state locking, local state | S3 remote backend with locking, KMS encryption, Secrets Manager, VPC security groups |
| **Observability** | `console.log` only, stack traces leaked to clients, no metrics or traces | OpenTelemetry tracing, Prometheus metrics, structured logs, Grafana dashboards |
| **Backups & Disaster Recovery** | Runbook is "call Bikash", restore is "TODO", zero backup retention | Verified nightly dumps, KMS encryption, tested restore scripts, actionable runbook |

---

## How to Use This Lab

1. **Read the Master Guide**: Check [IMPROVEMENTS.md](IMPROVEMENTS.md) for an in-depth breakdown of all 83 defects, explaining from first principles **why** the nightmare approach fails and **how** the pristine approach fixes it.
2. **Explore the Nightmare Codebase**: Browse `tiffin-nightmare/` to observe the anti-patterns in context. Run `grep -rn "AUDIT-" tiffin-nightmare/` to trace all defect markers.
3. **Inspect the Reference Implementation**: Explore `tiffin-pristine/` to study production-ready manifests, Docker multi-stage configurations, GitHub Actions workflows, Terraform modules, and test suites.
4. **Run the Disaster Recovery Drill**: Follow the runbook in [`tiffin-pristine/docs/RUNBOOK-dr-drill.md`](tiffin-pristine/docs/RUNBOOK-dr-drill.md) to practice live triage and database restoration.

---

## Quick Start

### 1. Running `tiffin-nightmare` (The Anti-Pattern Stack)

```bash
cd tiffin-nightmare
docker compose up -d --build
```
- Test health check: `curl http://localhost:3000/health`
- Test menu endpoint: `curl http://localhost:3000/menu`
- Test the SQL injection defect: `curl "http://localhost:3000/orders/1'%20OR%20'1'='1"`
- Inspect exposed environment variables: `curl http://localhost:3000/debug/env`

Tear down:
```bash
docker compose down -v
```

---

### 2. Running `tiffin-pristine` (The Production Reference Stack)

```bash
cd tiffin-pristine
cp .env.example .env        # review local environment variables
npm install                 # install dependencies
docker compose up -d --build # starts isolated postgres and app container
npm run migrate             # run database migrations
npm test                    # run unit and integration test suite
```
- Test liveness probe: `curl http://127.0.0.1:3000/healthz`
- Test readiness probe: `curl http://127.0.0.1:3000/readyz`
- Test menu endpoint: `curl http://127.0.0.1:3000/menu`
- Test metrics: `curl http://127.0.0.1:3000/metrics`

Run code quality & security checks:
```bash
npm run lint         # ESLint flat config with security plugin
npm run format       # Prettier check
npm run test:coverage # Vitest coverage report
```

Tear down:
```bash
docker compose down -v
```

---

## Project Structure

```
.
├── IMPROVEMENTS.md                 # Definitive deep-dive guide: Wrong Way vs Right Way for all 83 defects
├── README.md                       # Lab overview, story, and quickstart
│
├── tiffin-nightmare/               # The legacy codebase left by Bikash
│   ├── .env                        # Committed production credentials (Anti-pattern)
│   ├── AUDIT-MARKERS.md            # Distribution index of AUDIT-01 to AUDIT-83
│   ├── Dockerfile                  # Single-stage root build with bloated tooling
│   ├── docker-compose.yml          # Unbounded network bindings, no volumes
│   ├── .github/workflows/          # Vulnerable CI/CD pipelines
│   ├── k8s/                        # High-privilege pod escape manifests
│   ├── src/                        # Express app with SQL injection & PII leaks
│   └── terraform/                  # Hardcoded credentials and local state
│
└── tiffin-pristine/                # The production reference architecture
    ├── .env.example                # Safe environment template
    ├── Dockerfile                  # Multi-stage, unprivileged, dumb-init, pinned
    ├── docker-compose.yml          # Secure loopback bindings and healthcheck orchestration
    ├── .github/workflows/          # 4-gate pipeline with OIDC and SHA pinning
    ├── k8s/                        # PSA-restricted Kustomize base and overlays
    ├── src/                        # Zod validation, parameterized queries, structured logging
    ├── db/migrations/              # Forward-only SQL migrations
    ├── docs/                       # Architecture decisions and DR runbook
    ├── observability/              # Prometheus alerts and Grafana dashboard
    ├── scripts/                    # Verified backup and restore tooling
    └── terraform/                  # Remote S3 backend, KMS, VPC, and RDS modules
```
