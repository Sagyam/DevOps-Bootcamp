# The Tiffin Engineering & Security Audit: Improvements Guide

This document is the definitive guide to the **Tiffin Audit Lab**. It details all **83 planted defects** (`AUDIT-01` to `AUDIT-83`) alongside over **20 architectural improvements**, explaining **why the anti-pattern is dangerous** and **how the production standard fixes it**.

---

## Severity Classification

- **Critical**: Direct remote code execution (RCE), credential theft, trivial container escape, or guaranteed unrecoverable data loss.
- **High**: Severe security vulnerability, network exposure, or operational failure under standard production conditions.
- **Medium**: Configuration defect that degrades reliability, causes deployment race conditions, or violates platform hygiene.
- **Low**: Tooling omission, deprecated syntax, or suboptimal maintainability.

---

## Table of Contents

1. [Section A: Repository Hygiene, Secrets & Supply Chain (AUDIT-01 to 02 + Unmarked)](#section-a-repository-hygiene-secrets-supply-chain)
2. [Section B: Application Code & API Security (`src/`) (AUDIT-03 to 17 + Unmarked)](#section-b-application-code-api-security)
3. [Section C: Docker & Containerization (AUDIT-18 to 33 + Unmarked)](#section-c-docker-containerization)
4. [Section D: CI/CD & GitHub Actions Security (AUDIT-34 to 47 + Unmarked)](#section-d-cicd-github-actions-security)
5. [Section E: Kubernetes Orchestration & Workload Security (AUDIT-48 to 65 + Unmarked)](#section-e-kubernetes-orchestration-workload-security)
6. [Section F: Terraform & Infrastructure as Code (AUDIT-66 to 81 + Unmarked)](#section-f-terraform-infrastructure-as-code)
7. [Section G: Disaster Recovery & Backups (AUDIT-82 to 83 + Unmarked)](#section-g-disaster-recovery-backups)
8. [Master Defect Index](#master-defect-index)

---

## Section A: Repository Hygiene, Secrets & Supply Chain

### AUDIT-01: `package-lock.json` is Gitignored
- **Severity**: High
- **Location**: `tiffin-nightmare/.gitignore`

#### The Wrong Way (Nightmare)
```gitignore
# AUDIT-01
package-lock.json
```

#### Why This Is Wrong & Dangerous
When `package-lock.json` is excluded from source control:
1. **Non-Reproducible Builds**: Every `npm install` performs fresh semver resolution (e.g. `^4.16.0`). Different team members and CI runners end up with different dependency trees.
2. **`npm ci` Fails**: The clean, fast, deterministic install command required in CI/CD pipelines (`npm ci`) requires a lockfile and will error immediately if one is missing.
3. **Supply Chain Vulnerability**: A compromised sub-dependency updated upstream will be pulled automatically into production without code review.

#### The Right Way (Pristine)
In `tiffin-pristine/.gitignore`:
- `package-lock.json` is committed to git.
- Dependencies are locked to exact checksums and tree structures.

```bash
# In pristine repository setup:
npm install             # Generates exact package-lock.json
git add package-lock.json
```

---

### AUDIT-02: `.env` Committed to Git with Live Credentials
- **Severity**: Critical
- **Location**: `tiffin-nightmare/.env`

#### The Wrong Way (Nightmare)
```ini
# AUDIT-02
NODE_ENV=production
PORT=3000
DATABASE_URL=postgres://tiffin:Tiffin@2023@prod-db.internal:5432/tiffin
JWT_SECRET=supersecret123
AWS_ACCESS_KEY_ID=AKIAQYX7EXAMPLE4TIFF
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
ADMIN_PASSWORD=admin
```

#### Why This Is Wrong & Dangerous
1. **Permanent Credential Compromise**: Committing secrets to git pushes them to remote servers and preserves them in commit history. Even if the file is deleted in a later commit, anyone with clone access can recover the credentials via `git log` or `git checkout`.
2. **Rotation Required**: Simply running `git rm .env` does **not** secure the system. The AWS keys and passwords must be immediately revoked and rotated in the cloud provider.

#### The Right Way (Pristine)
In `tiffin-pristine/`:
1. `.gitignore` ignores all `.env` files except `.env.example`:
   ```gitignore
   .env
   .env.*
   !.env.example
   ```
2. A sanitised template `.env.example` is committed with placeholder values:
   ```ini
   NODE_ENV=development
   PORT=3000
   PGHOST=localhost
   PGPORT=5432
   PGDATABASE=tiffin
   PGUSER=tiffin
   PGPASSWORD=change-me-locally
   ```
3. In production Kubernetes, secrets are injected at runtime via AWS Secrets Manager and External Secrets Operator.

---

### Section A Unmarked Improvements: Repository & Developer Standards
In `tiffin-nightmare`, there are no developer hygiene configurations. In `tiffin-pristine`, standard tools are established:
- **`.dockerignore`**: Prevents `.git`, `.env`, and `node_modules` from leaking into Docker build contexts.
- **`.editorconfig`**: Enforces UTF-8, LF line endings, 2-space indentation across all IDEs.
- **`.gitleaks.toml`**: Configures automated pre-commit and CI secret scanning.
- **`.github/dependabot.yml`**: Automates security vulnerability patching for npm and GitHub Actions.
- **`.github/pull_request_template.md`**: Provides a standard checklist for operational impact, rollback plans, and test coverage.

---

## Section B: Application Code & API Security

### AUDIT-03: Wildcard CORS with Credentials
- **Severity**: High
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-03
app.use(cors({ origin: '*', credentials: true }));
```

#### Why This Is Wrong & Dangerous
`origin: '*'` tells browsers that any website on the internet can make cross-origin requests to this API. Combining `origin: '*'` with `credentials: true` creates a severe Cross-Origin Resource Sharing vulnerability: malicious websites visited by an authenticated user can execute requests on their behalf and read the responses. Modern browsers explicitly reject this combination for security, causing client failures.

#### The Right Way (Pristine)
In `tiffin-pristine/src/app.js`:
```javascript
// Explicit allowlist, no wildcard, credentials restricted
const allowedOrigins = new Set(['https://tiffin.example.np']);
app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (origin && allowedOrigins.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  next();
});
```

---

### AUDIT-04: Static `/health` Endpoint Serving Both Liveness & Readiness
- **Severity**: High
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-04
app.get('/health', function (req, res) {
  res.send('OK');
});
```

#### Why This Is Wrong & Dangerous
1. **Liveness vs. Readiness Confusion**: Liveness answers *"Is the Node process alive or hung?"*; Readiness answers *"Can this pod currently handle incoming customer traffic?"*.
2. **False Positives & Outage Amplification**: Because `/health` always returns `200 OK`, Kubernetes will route user traffic to pods even if the database is dead. Conversely, if a single probe checks the database and restarts the pod on DB failure, a momentary database glitch causes Kubernetes to kill and restart every single pod at the exact same moment, turning a slow query into a total blackout.

#### The Right Way (Pristine)
In `tiffin-pristine/src/routes/health.js`:
```javascript
// /healthz (Liveness): Checks process responsiveness only. Never touches DB.
healthRouter.get('/healthz', (_req, res) => {
  res.json({ status: 'ok' });
});

// /readyz (Readiness): Verifies database connectivity.
healthRouter.get('/readyz', async (_req, res) => {
  const dbOk = await checkHealth();
  if (!dbOk) return res.status(503).json({ status: 'degraded', db: 'unreachable' });
  res.json({ status: 'ready', db: 'connected' });
});
```

---

### AUDIT-05: Stack Traces Leaked in Error Responses
- **Severity**: Medium
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-05
console.log("db error", err);
res.status(500).send(err.stack);
```

#### Why This Is Wrong & Dangerous
Sending raw `err.stack` to HTTP clients exposes server directory paths, operating system details, third-party library versions, internal function names, and raw SQL queries. Attackers use this information to fingerprint the infrastructure and craft targeted exploits.

#### The Right Way (Pristine)
In `tiffin-pristine/src/app.js`:
```javascript
// Central error handler: Stack traces logged internally, never returned to client
app.use((err, req, res, _next) => {
  req.log.error({ err }, 'unhandled error');
  res.status(500).json({
    error: 'internal_error',
    request_id: req.id,
    ...(config.NODE_ENV === 'development' ? { detail: err.message } : {}),
  });
});
```

---

### AUDIT-06: SQL Injection via String Concatenation
- **Severity**: Critical
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-06
var sql = "SELECT * FROM orders WHERE id = '" + req.params.id + "'";
db.query(sql, function (err, result) {
  if (err) { res.status(500).send(err.stack); return; }
  res.json(result.rows[0]);
});
```

#### Why This Is Wrong & Dangerous
Concatenating user input directly into SQL strings allows an attacker to alter the query logic.
- **Exploit Example**: Requesting `GET /orders/1'%20OR%20'1'='1` turns the query into `SELECT * FROM orders WHERE id = '1' OR '1'='1'`, dumping unauthorized customer data.
- **Catastrophic Payloads**: An attacker can inject stacked queries: `1'; DROP TABLE orders; --`, wiping out production tables.

#### The Right Way (Pristine)
In `tiffin-pristine/src/routes/orders.js`:
```javascript
// Input validated as UUID with Zod, and parameterized SQL query ($1)
ordersRouter.get('/orders/:id', validate(orderIdSchema, 'params'), async (req, res) => {
  const result = await query('SELECT * FROM orders WHERE id = $1', [req.params.id]);
  if (!result.rows[0]) return res.status(404).json({ error: 'order_not_found' });
  res.json(result.rows[0]);
});
```

---

### AUDIT-07: Missing Input Validation on Request Bodies
- **Severity**: High
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-07
var item = req.body.item_id;
var qty = req.body.quantity;
var phone = req.body.customer_phone;
```

#### Why This Is Wrong & Dangerous
The application blindly trusts all values supplied in JSON request bodies. An attacker can send negative quantities (`quantity: -500`), invalid types (`quantity: "abc"`), oversized strings that consume memory, or extra unvalidated fields.

#### The Right Way (Pristine)
In `tiffin-pristine/src/schemas.js`:
```javascript
import { z } from 'zod';

const phone = z.string().trim().regex(/^(\+977)?9[78]\d{8}$/, 'must be a valid Nepali mobile number');

export const createOrderSchema = z.object({
  item_id: z.string().uuid('item_id must be a UUID'),
  quantity: z.number().int().min(1).max(20),
  customer_phone: phone,
  note: z.string().max(200).optional(),
});
```

---

### AUDIT-08: Plaintext PII (Phone Numbers) Logged
- **Severity**: High
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-08
console.log('new order from ' + phone + ' item=' + item + ' qty=' + qty);
```

#### Why This Is Wrong & Dangerous
Logging Personally Identifiable Information (PII) like phone numbers violates privacy compliance laws (e.g. GDPR, local privacy acts). Once written to stdout, phone numbers persist in plain text in log aggregators (Loki, CloudWatch, Datadog) forever and are accessible to anyone with log read permissions.

#### The Right Way (Pristine)
In `tiffin-pristine/src/logger.js`:
```javascript
// Pino structured logger with automated redaction of sensitive fields
export const logger = pino({
  redact: {
    paths: ['customer_phone', '*.customer_phone', 'req.body.customer_phone', 'password', '*.password'],
    censor: '[REDACTED]',
  },
});
```

---

### AUDIT-09: MD5 Hashing & Non-Constant-Time Password Comparison
- **Severity**: High
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-09
app.post('/admin/login', function (req, res) {
  var hash = md5(req.body.password);
  if (hash === md5(process.env.ADMIN_PASSWORD)) {
    res.json({ token: 'admin-' + Date.now() });
  } else {
    res.status(401).send('bad password');
  }
});
```

#### Why This Is Wrong & Dangerous
1. **Broken Cryptography**: MD5 is broken and vulnerable to collision and pre-image attacks.
2. **Timing Attack**: Standard string equality (`===`) exits on the first mismatched byte, allowing attackers to measure response times down to nanoseconds to guess characters one by one.
3. **Static Token**: The returned token `admin-Date.now()` is completely predictable and forged easily without a digital signature (JWT with HMAC-SHA256 or asymmetric key).

#### The Right Way (Pristine)
- Passwords must be hashed using `argon2id` or `bcrypt` with unique salts.
- String comparisons for secrets must use `crypto.timingSafeEqual()`.
- Authentication tokens must use cryptographically signed JWTs or opaque session store tokens.

---

### AUDIT-10: `/debug/env` Route Exposing Secrets
- **Severity**: Critical
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-10
app.get('/debug/env', function (req, res) {
  res.json(process.env);
});
```

#### Why This Is Wrong & Dangerous
Exposes the entire runtime environment to anyone on the network with a single `GET /debug/env` call. This reveals database credentials, JWT secrets, cloud API keys, and internal service hostnames.

#### The Right Way (Pristine)
In `tiffin-pristine/`:
- Debug endpoints that dump raw environment or memory state are **deleted**.
- Configuration validation happens in `src/config.js`, which parses and seals needed config at boot without ever exposing an API endpoint.

---

### AUDIT-11: Missing Graceful SIGTERM Handling
- **Severity**: Medium
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-11
app.listen(process.env.PORT || 3000, function () {
  console.log('listening');
});
```

#### Why This Is Wrong & Dangerous
When Kubernetes performs a rolling update or scales down a pod, it sends a `SIGTERM` signal. Without a SIGTERM handler, Node abruptly terminates immediately, severing in-flight client connections and causing 502 Bad Gateway errors for active users.

#### The Right Way (Pristine)
In `tiffin-pristine/src/server.js`:
```javascript
function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down');

  const force = setTimeout(() => {
    logger.error('graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, config.SHUTDOWN_TIMEOUT_MS);
  force.unref();

  server.close(async () => {
    try {
      await closePool(); // Drain DB connections cleanly
      logger.info('shutdown complete');
      process.exit(0);
    } catch (err) {
      logger.error({ err }, 'error during shutdown');
      process.exit(1);
    }
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
```

---

### AUDIT-12: Unstructured Logging Without Request IDs
- **Severity**: Medium
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-12
console.log('listening');
```

#### Why This Is Wrong & Dangerous
Freeform text printed via `console.log` cannot be filtered, parsed, or queried effectively in centralized log aggregators (e.g. Loki, Elasticsearch). Without unique request IDs, tracking a single user's request across multiple log entries or microservices is impossible during an incident.

#### The Right Way (Pristine)
In `tiffin-pristine/src/logger.js` & `app.js`:
- Uses JSON-formatted `pino` and `pino-http`.
- Generates a UUID `x-request-id` for every request and attaches it to every child log entry and response header.

---

### AUDIT-13: Missing Metrics & Distributed Tracing
- **Severity**: Medium
- **Location**: `tiffin-nightmare/src/index.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-13
// No /metrics endpoint, no tracing instrumentation
```

#### Why This Is Wrong & Dangerous
Without metrics, operators have zero visibility into request latency (p95/p99), HTTP error rates, or connection pool saturation until customers complain. Without tracing, identifying which database query or downstream service caused a slow request requires guesswork.

#### The Right Way (Pristine)
In `tiffin-pristine/src/metrics.js` & `src/tracing.js`:
- **Prometheus Scrape Endpoint**: Exposes standard latency histograms and status counters on `GET /metrics`.
- **OpenTelemetry SDK**: Automatically traces HTTP requests and Postgres queries, forwarding spans to OpenTelemetry Collector / Tempo.

---

### AUDIT-14: Hardcoded Fallback Connection String & `ssl: false`
- **Severity**: High
- **Location**: `tiffin-nightmare/src/db.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-14
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://tiffin:tiffin@db:5432/tiffin',
  ssl: false
});
```

#### Why This Is Wrong & Dangerous
1. **Fallback Credential**: Embedding default passwords in source code risks running against local databases or unintended instances when environment variables are omitted.
2. **Unencrypted Database Traffic**: `ssl: false` sends queries, customer data, and database credentials over the network in plaintext.

#### The Right Way (Pristine)
In `tiffin-pristine/src/config.js` & `src/db.js`:
- Environment variables (`PGHOST`, `PGUSER`, `PGDATABASE`, `PGPASSWORD`) are strictly validated at startup with Zod. The application refuses to boot if any variable is missing.
- SSL mode defaults to encrypted connections (`ssl: config.PGSSLMODE === 'require' ? { rejectUnauthorized: true } : false`).

---

### AUDIT-15: Postgres Pool Error Handler Fails Silently
- **Severity**: Medium
- **Location**: `tiffin-nightmare/src/db.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-15
pool.on('error', function (err) {
  console.log('pool error', err);
});
```

#### Why This Is Wrong & Dangerous
When an idle database client encounters a fatal socket error or disconnection, logging it with `console.log` leaves the pool in an indeterminate state without emitting metrics or notifying orchestrators. If all connections in the pool die, the app stays running as a zombie process that fails all user requests.

#### The Right Way (Pristine)
In `tiffin-pristine/src/db.js`:
```javascript
pool.on('error', (err) => {
  logger.fatal({ err }, 'idle client error in database pool');
});
```
The error is logged at `fatal` level, triggering alerting rules and readiness probe failures so Kubernetes stops routing traffic to the bad instance.

---

### AUDIT-16: Query Wrapper Accepts `params` and Discards Them
- **Severity**: Critical
- **Location**: `tiffin-nightmare/src/db.js`

#### The Wrong Way (Nightmare)
```javascript
module.exports = {
  // AUDIT-16
  query: function (text, params, cb) {
    if (typeof params === 'function') { cb = params; params = undefined; }
    return pool.query(text, cb); // params is ignored!
  }
};
```

#### Why This Is Wrong & Dangerous
**This is the root cause of AUDIT-06.** The database wrapper method accepted a `params` argument but discarded it before calling `pool.query(text, cb)`. Any developer attempting to use parameterized queries (`db.query("SELECT * WHERE id = $1", [id])`) would find that parameters failed, forcing everyone to concatenate raw strings throughout the codebase.

#### The Right Way (Pristine)
In `tiffin-pristine/src/db.js`:
```javascript
export function query(text, params) {
  const start = performance.now();
  return pool.query(text, params).finally(() => {
    const duration = performance.now() - start;
    logger.trace({ text, duration }, 'executed query');
  });
}
```
Properly passes parameterized values array directly to the Postgres driver, enforcing separation of code and user data at the protocol level.

---

### AUDIT-17: Tautological Smoke Test
- **Severity**: High
- **Location**: `tiffin-nightmare/test/smoke.test.js`

#### The Wrong Way (Nightmare)
```javascript
// AUDIT-17
test('it works', () => {
  expect(1 + 1).toBe(2);
});
```

#### Why This Is Wrong & Dangerous
The only test in the repository tests basic math in the test runner itself, not any application logic, API route, or database query. In `package.json`, `"test": "echo \"no tests yet\" && exit 0"` guarantees CI builds pass 100% of the time, even if the entire application is broken.

#### The Right Way (Pristine)
In `tiffin-pristine/test/`:
- **Unit Tests (`test/unit/`)**: Fast, pure tests verifying input schemas, validation constraints, and edge cases.
- **Integration Tests (`test/integration/`)**: Real HTTP calls via Supertest against real Postgres instances testing end-to-end order creation, health probes, metrics, and SQL injection prevention.
- **Coverage Ratchet**: Enforces minimum 70% line and branch coverage gates in CI.

---

## Section C: Docker & Containerization

### AUDIT-18: Unpinned `FROM node:latest` Base Image
- **Severity**: High
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-18
FROM node:latest
```

#### Why This Is Wrong & Dangerous
`:latest` is a floating tag. Whenever Docker builds the image, it pulls whatever Node.js version is currently latest. An upstream major version jump (e.g. Node 20 to Node 22 to Node 24) or Debian distro upgrade will silently break production builds with no code changes in your repository.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
```dockerfile
FROM node:22.17-bookworm-slim AS runtime
```
Pinned to a specific, minimal LTS release (`22.17-bookworm-slim`), ensuring predictable, reproducible image layers across environments.

---

### AUDIT-19: Single-Stage Build Shipping Build Artifacts
- **Severity**: Medium
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-19
WORKDIR /app
COPY . .
RUN npm install
```

#### Why This Is Wrong & Dangerous
A single-stage build bundles build tools, devDependencies, temporary build caches, test frameworks, and raw source assets directly into the final production image. This swells image size (500MB+ vs 120MB) and dramatically expands the attack surface.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
Uses a multi-stage Docker build:
1. **`deps` Stage**: Runs `npm ci --omit=dev` to isolate only production dependencies.
2. **`test` Stage**: Installs devDependencies, runs linters, formatters, and unit tests inside Docker.
3. **`runtime` Stage**: Copies only production `node_modules` and required application code into a clean, minimal container.

---

### AUDIT-20: `COPY . .` Before `npm install`
- **Severity**: High
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-20
COPY . .
RUN npm install
```

#### Why This Is Wrong & Dangerous
1. **Destroys Docker Layer Caching**: Any change to a single line in a README or JavaScript file invalidates the `COPY . .` layer, forcing Docker to re-run `npm install` and download all dependencies on every build.
2. **Leaks Secrets into Image History**: Without a `.dockerignore`, `COPY . .` copies `.git/` histories and `.env` secret files directly into the image layers.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
```dockerfile
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev --ignore-scripts
COPY src ./src
COPY db ./db
```
Manifests are copied first so dependency installation layers are cached until `package.json` actually changes.

---

### AUDIT-21: `npm install` Instead of `npm ci`
- **Severity**: High
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-21
RUN npm install
```

#### Why This Is Wrong & Dangerous
`npm install` modifies `package-lock.json` on the fly and resolves non-pinned dependency ranges, leading to drift. Furthermore, it executes arbitrary `preinstall`/`postinstall` lifecycle scripts from npm packages.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
```dockerfile
RUN npm ci --omit=dev --ignore-scripts
```
Installs exact locked dependencies deterministically without executing unverified third-party postinstall scripts.

---

### AUDIT-22: Installing Debugging & Network Attack Tools
- **Severity**: High
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-22
RUN apt-get update && apt-get install -y curl vim net-tools telnet
```

#### Why This Is Wrong & Dangerous
Installing network probing tools (`telnet`, `net-tools`, `vim`, `curl`) inside a production container equips an attacker with an interactive exploitation kit if they achieve remote code execution. Additionally, failing to clean apt caches (`/var/lib/apt/lists/*`) bloats image size.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
Only installs the minimal process supervisor `dumb-init`:
```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends dumb-init=1.2.5-2 \
 && rm -rf /var/lib/apt/lists/*
```

---

### AUDIT-23: Production Connection String Baked into Image ENV
- **Severity**: Critical
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-23
ENV DATABASE_URL=postgres://tiffin:Tiffin@2023@prod-db.internal:5432/tiffin
```

#### Why This Is Wrong & Dangerous
Environment variables declared with `ENV` in a Dockerfile are permanently recorded in image metadata. Anyone with read access to the Docker container registry can view the production database password using `docker history` or `docker inspect`, even across public registries.

#### The Right Way (Pristine)
- No secrets or connection strings are declared in Dockerfiles.
- Secrets are passed at runtime via Kubernetes Secrets or Docker Compose environment files.

---

### AUDIT-24: Missing Container `HEALTHCHECK` Instruction
- **Severity**: Low
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-24
# No HEALTHCHECK instruction provided
```

#### Why This Is Wrong & Dangerous
Without a `HEALTHCHECK` directive, Docker daemon and Docker Compose cannot detect if the Node application is deadlocked or unable to respond to traffic. The container status will falsely remain `Up (healthy)`.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
```

---

### AUDIT-25: Shell-Form `CMD` Running as Root
- **Severity**: High
- **Location**: `tiffin-nightmare/Dockerfile`

#### The Wrong Way (Nightmare)
```dockerfile
# AUDIT-25
CMD npm start
```

#### Why This Is Wrong & Dangerous
1. **Runs as Root**: By default, Docker containers run with UID 0 (root). If a vulnerability in Node or Express allows an escape, the attacker gains root on the host machine.
2. **Shell Form Swallows Signals**: `CMD npm start` launches `/bin/sh -c "npm start"`, making `sh` PID 1. Shells do not forward `SIGTERM` signals to child processes (`node`), preventing graceful shutdown.

#### The Right Way (Pristine)
In `tiffin-pristine/Dockerfile`:
```dockerfile
USER node
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]
```
- Switches to non-root `USER node` (UID 1000).
- Uses `dumb-init` as PID 1 to properly handle process reaping and signal forwarding.
- Uses exec-form array syntax `["node", "src/server.js"]`.

---

### AUDIT-26: Obsolete Compose `version: "2"`
- **Severity**: Low
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-26
version: "2"
```

#### Why This Is Wrong & Dangerous
The `version` attribute in Compose files was deprecated by Docker and is obsolete in modern Compose Specification.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
The top-level `version` string is removed, and a project `name: tiffin` is defined.

---

### AUDIT-27: App Bound to `0.0.0.0:3000`
- **Severity**: Medium
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-27
ports:
  - "0.0.0.0:3000:3000"
```

#### Why This Is Wrong & Dangerous
Publishing on `0.0.0.0` exposes the local development server to the entire local area network (LAN) and public Wi-Fi.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
```yaml
ports:
  - "127.0.0.1:3000:3000"
```
Binds exclusively to the loopback interface (`127.0.0.1`).

---

### AUDIT-28: Bind-Mounting Entire Host Tree into Container
- **Severity**: Medium
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-28
volumes:
  - .:/app
```

#### Why This Is Wrong & Dangerous
Bind-mounting `.` directly over `/app` overwrites the container's isolated `/app/node_modules` with host binaries (which may fail due to OS/architecture mismatch) and bypasses container immutability.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
Uses the container image's runtime build stage directly without host file system overrides.

---

### AUDIT-29: `sleep 10` for Database Dependency Management
- **Severity**: Medium
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-29
command: sh -c "sleep 10 && npm start"
```

#### Why This Is Wrong & Dangerous
Hardcoded `sleep` delays create race conditions: on busy or slow machines, Postgres takes longer than 10 seconds to initialize, causing the app to crash. On fast machines, it wastes 10 seconds of developer time on every startup.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
```yaml
depends_on:
  db:
    condition: service_healthy
```
Pairs with Postgres `healthcheck` (`pg_isready`) so the app launches the millisecond the database is ready.

---

### AUDIT-30: Postgres Unpinned `latest` Tag
- **Severity**: High
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-30
image: postgres:latest
```

#### Why This Is Wrong & Dangerous
When a new major version of PostgreSQL releases (e.g. Postgres 16 -> 17 -> 18), running `docker compose pull` upgrades the database engine. PostgreSQL cannot automatically read on-disk data files from an older major version without `pg_upgrade`, causing database startup failure and data lockout.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
```yaml
image: postgres:16.9-bookworm
```
Pinned to a stable, specific major and minor release.

---

### AUDIT-31: Postgres Published on `5432:5432` to LAN
- **Severity**: High
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-31
ports:
  - "5432:5432"
```

#### Why This Is Wrong & Dangerous
Binds port 5432 to `0.0.0.0`, allowing anyone on the local network or internet to attempt authentication against the database.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
```yaml
ports:
  - "127.0.0.1:5432:5432"
```
Bound strictly to loopback (`127.0.0.1`).

---

### AUDIT-32: Hardcoded Password in Compose
- **Severity**: High
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-32
- POSTGRES_PASSWORD=tiffin
```

#### Why This Is Wrong & Dangerous
Hardcoding passwords in repository manifests leads to credential reuse across environments and commits secrets to version control.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
```yaml
POSTGRES_PASSWORD: ${PGPASSWORD:?set PGPASSWORD in your .env}
```
Requires `PGPASSWORD` to be explicitly provided in local `.env`, failing early if absent.

---

### AUDIT-33: Missing Database Storage Volume (Data Loss Guarantee 1)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/docker-compose.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-33
# No volume defined for the Postgres container
```

#### Why This Is Wrong & Dangerous
**This is Data Loss Guarantee #1.** Without a named volume or persistent mount, Postgres writes data into the container's ephemeral writable layer. Running `docker compose down` deletes the container and permanently destroys all database records.

#### The Right Way (Pristine)
In `tiffin-pristine/docker-compose.yml`:
```yaml
volumes:
  - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```
Persists data to a named Docker volume `pgdata` that survives container restarts and upgrades.

---

## Section D: CI/CD & GitHub Actions Security

### AUDIT-34: `on: push` Without Branch Filtering
- **Severity**: Medium
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-34
on: push
```

#### Why This Is Wrong & Dangerous
Triggers complete workflow builds on every push to any branch or tag, consuming runner minutes and cluttering CI logs on work-in-progress drafts.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/ci.yml`:
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

---

### AUDIT-35: Missing `permissions:` Block
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-35
# No permissions block defined
```

#### Why This Is Wrong & Dangerous
When no permissions block is specified, GitHub Actions assigns the default `GITHUB_TOKEN` broad write permissions (contents, packages, deployments, pull requests). If a compromised dependency runs during CI, it can hijack the token to push malicious code directly into the repository.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/ci.yml`:
```yaml
permissions:
  contents: read
```
Adheres to the Principle of Least Privilege.

---

### AUDIT-36: Mutable Action Reference at master
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-36
- uses: actions/checkout@master
```

#### Why This Is Wrong & Dangerous
Branch tags like `@master` or `@v1` are mutable references. If an attacker compromises the upstream action repository or moves the branch ref, your workflow will immediately execute attacker-modified code in your CI environment.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/ci.yml`:
```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```
Pinned to immutable full commit SHAs with semantic version comments.

---

### AUDIT-37: `npm install` in CI Without Dependency Cache
- **Severity**: Low
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-37
- run: npm install
```

#### Why This Is Wrong & Dangerous
`npm install` slows down CI runs and mutates dependencies.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/ci.yml`:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: 'npm'
- run: npm ci
```

---

### AUDIT-38: `continue-on-error: true` on Test Step
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-38
- run: npm test
  continue-on-error: true
```

#### Why This Is Wrong & Dangerous
`continue-on-error: true` forces the test step to report success even when tests fail. Broken code and regression bugs pass CI and proceed straight to deployment.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/ci.yml`:
`continue-on-error` is removed. Test failures halt the pipeline immediately.

---

### AUDIT-39: Database Secret Echoed into CI Logs
- **Severity**: Critical
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-39
- name: check db connection
  run: |
    echo "connecting with $DB_PASSWORD"
    echo "::debug::password is $DB_PASSWORD"
  env:
    DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

#### Why This Is Wrong & Dangerous
Printing secrets to stdout writes them into public CI job logs. Using `::debug::` prints the unmasked secret whenever workflow debug logging is enabled.

#### The Right Way (Pristine)
Secrets are never printed to stdout. Tools consume secrets via environment variables or secret injection files.

---

### AUDIT-40: Pushing Unscanned `:latest` Tag on Every Commit
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-40
- name: build and push
  run: |
    docker build -t bikash/tiffin:latest .
    docker push bikash/tiffin:latest
```

#### Why This Is Wrong & Dangerous
1. **Mutable Tag**: Overwriting `:latest` on every commit makes it impossible to know which commit is running in production.
2. **Missing Security Scans**: Images are pushed without vulnerability scanning (Trivy) or cryptographic signing (Cosign).

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/cd.yml`:
- Images are tagged with immutable commit SHAs (`sha-<hash>`) and semantic release tags.
- Trivy scans images for critical CVEs before pushing.
- Images are cryptographically signed with Cosign keyless signatures.

---

### AUDIT-41: Missing Concurrency Control
- **Severity**: Low
- **Location**: `tiffin-nightmare/.github/workflows/ci.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-41
# No concurrency group
```

#### Why This Is Wrong & Dangerous
Rapid successive pushes queue multiple workflow runs simultaneously, wasting runners and allowing older pushes to overwrite newer deployments.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/ci.yml`:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

---

### AUDIT-42: Arbitrary Code Execution via `pull_request_target`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/.github/workflows/deploy.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-42
on:
  pull_request_target:
    types: [opened, synchronize]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          # AUDIT-44
          ref: ${{ github.event.pull_request.head.ref }}
```

#### Why This Is Wrong & Dangerous
**This is the single most catastrophic CI security vulnerability in the lab.**
`pull_request_target` runs in the context of the base repository and has full access to repository secrets (like `AWS_SECRET_ACCESS_KEY` and `KUBECONFIG`). Combining `pull_request_target` with checking out the pull request head branch (`github.event.pull_request.head.ref`) allows **any stranger on the internet** to open a pull request from a fork containing malicious code in `package.json` or build scripts. GitHub Actions will execute their untrusted code with your production AWS credentials.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/`:
1. CI runs on `pull_request` (no access to production secrets).
2. CD deployments trigger only on protected Git tags pushed to `main`.

---

### AUDIT-43: Missing Environment Protection & Approval Gates
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/deploy.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-43
# No environment gate
```

#### Why This Is Wrong & Dangerous
Deployments execute automatically without approval or environment-specific secret isolation.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/cd.yml`:
```yaml
environment:
  name: production
  url: https://tiffin.example.np
```
Enforces GitHub Environment Protection Rules (required manual approvals and branch restrictions).

---

### AUDIT-44: Checking Out Mutable Branch Ref
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/deploy.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-44
ref: ${{ github.event.pull_request.head.ref }}
```

#### Why This Is Wrong & Dangerous
`head.ref` is a branch name that can change mid-run.

#### The Right Way (Pristine)
Deployments checkout immutable commit SHAs (`github.sha`).

---

### AUDIT-45: Long-Lived Static AWS Credentials in CI Secrets
- **Severity**: Critical
- **Location**: `tiffin-nightmare/.github/workflows/deploy.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-45
- name: configure aws
  run: |
    aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

#### Why This Is Wrong & Dangerous
Static IAM user keys never expire on their own. If leaked through CI logs or action exploits, attackers have perpetual access to your AWS account.

#### The Right Way (Pristine)
In `tiffin-pristine/.github/workflows/cd.yml`:
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/tiffin-github-deploy
    aws-region: ap-south-1
```
Uses **OpenID Connect (OIDC)** to exchange short-lived tokens for temporary AWS STS credentials without storing any static secret keys.

---

### AUDIT-46: Kubeconfig Stored in CI and Given `chmod 777`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/.github/workflows/deploy.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-46
- name: kubeconfig
  run: |
    mkdir -p ~/.kube
    echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config
    chmod 777 ~/.kube/config
```

#### Why This Is Wrong & Dangerous
1. **Cluster Admin Secret in CI**: Putting cluster credentials in CI makes CI a prime target.
2. **`chmod 777`**: Grants all users on the runner read/write/execute permissions.

#### The Right Way (Pristine)
Under modern GitOps (e.g. Argo CD):
- CI never holds cluster credentials.
- CI updates manifests in git; Argo CD reconciles cluster state from inside the Kubernetes cluster.

---

### AUDIT-47: Blind `kubectl apply` and `rollout restart`
- **Severity**: High
- **Location**: `tiffin-nightmare/.github/workflows/deploy.yml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-47
- name: deploy
  run: |
    kubectl apply -f k8s/
    kubectl rollout restart deployment/tiffin
```

#### Why This Is Wrong & Dangerous
1. **No Diff or Preview**: Applies manifests without checking what is changing or validating syntax.
2. **`rollout restart` Does Not Deploy Code**: Restarting a deployment that points to `:latest` does not guarantee new code if the image tag didn't change.

#### The Right Way (Pristine)
Manifests are validated via `kubeconform` in CI and synced via Kustomize or GitOps with clear diff logs.

---

## Section E: Kubernetes Orchestration & Workload Security

### AUDIT-48: Deploys to `default` Namespace Without PSA
- **Severity**: Medium
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-48
namespace: default
```

#### Why This Is Wrong & Dangerous
Running workloads in the `default` namespace mixes applications together and bypasses Pod Security Standards.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tiffin
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```
Enforces the Kubernetes **Restricted Pod Security Standard**.

---

### AUDIT-49: Single Replica (`replicas: 1`)
- **Severity**: High
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-49
replicas: 1
```

#### Why This Is Wrong & Dangerous
A single replica guarantees downtime during node maintenance, cluster upgrades, or pod crashes.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml` & `pdb.yaml`:
- Sets `replicas: 3` with `PodDisruptionBudget` (`minAvailable: 2`).
- Pairs with Horizontal Pod Autoscaler (`hpa.yaml`) to autoscale based on CPU and memory.

---

### AUDIT-50: Missing Deployment Strategy
- **Severity**: Medium
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-50
# No strategy block
```

#### Why This Is Wrong & Dangerous
Without explicit rollout parameters, deployments can terminate existing pods before new pods are ready.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml`:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

---

### AUDIT-51: `hostNetwork: true`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-51
hostNetwork: true
```

#### Why This Is Wrong & Dangerous
The pod shares the host node's network namespace. It can sniff all traffic on the node, bypass Kubernetes NetworkPolicies, and bind directly to node host ports.

#### The Right Way (Pristine)
`hostNetwork: true` is removed. The pod uses standard overlay pod networking.

---

### AUDIT-52: Unpinned `:latest` Image Tag with `Always` Pull Policy
- **Severity**: High
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-52
image: bikash/tiffin:latest
imagePullPolicy: Always
```

#### Why This Is Wrong & Dangerous
Pods starting on different nodes at different times may pull different versions of the `:latest` tag, resulting in a cluster running mismatched code simultaneously.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml`:
Images are pinned to immutable digest hashes or versioned Git SHA tags.

---

### AUDIT-53: High-Privilege Security Context (Root and Privileged)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-53
securityContext:
  privileged: true
  runAsUser: 0
  allowPrivilegeEscalation: true
```

#### Why This Is Wrong & Dangerous
`privileged: true` disables all container isolation. The container has access to all host devices, kernel capabilities, and root privileges.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml`:
```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
  privileged: false
```
Pod-level:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```

---

### AUDIT-54: Plaintext Secrets in Manifest Environment Variables
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-54
env:
  - name: DATABASE_URL
    value: "postgres://tiffin:Tiffin@2023@postgres:5432/tiffin"
  - name: ADMIN_PASSWORD
    value: "admin"
  - name: JWT_SECRET
    value: "supersecret123"
```

#### Why This Is Wrong & Dangerous
Secrets are hardcoded directly into committed YAML files.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml`:
Values are injected from Kubernetes Secrets (`secretKeyRef`) managed via External Secrets Operator.

---

### AUDIT-55: `hostPath: /` Mounted into Container
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-55
volumeMounts:
  - name: host
    mountPath: /host
volumes:
  - name: host
    hostPath:
      path: /
```

#### Why This Is Wrong & Dangerous
Mounting the host's root filesystem `/` into a privileged container allows trivial container escape. An attacker can write to `/etc/shadow`, read other containers' data, or install rootkits on the host.

#### The Right Way (Pristine)
Host mounts are strictly eliminated. Writable scratch space uses in-memory `emptyDir` mounts (`/tmp`).

---

### AUDIT-56: Missing Resource Requests and Limits
- **Severity**: High
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-56
# No resources block
```

#### Why This Is Wrong & Dangerous
1. **Unpredictable Scheduling**: Without `requests`, the Kubernetes scheduler cannot place pods accurately based on node capacity.
2. **Node Starvation**: Without `limits`, a memory leak in one pod can consume all host memory, causing the Linux OOM killer to evict critical system pods.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml`:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi # Memory limited; CPU unconstrained to prevent CFS throttling
```

---

### AUDIT-57: Missing Liveness, Readiness & Startup Probes
- **Severity**: High
- **Location**: `tiffin-nightmare/k8s/deployment.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-57
# No probes configured
```

#### Why This Is Wrong & Dangerous
Kubernetes cannot know if the pod has started or if it is healthy. It sends traffic immediately, before the application is listening, and keeps sending traffic even if the application is frozen.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/deployment.yaml`:
- **`startupProbe`**: Gives slow containers time to boot (`/healthz`).
- **`livenessProbe`**: Restarts wedged processes (`/healthz`).
- **`readinessProbe`**: Controls traffic routing based on database health (`/readyz`).

---

### AUDIT-58: API Service Type `LoadBalancer`
- **Severity**: Medium
- **Location**: `tiffin-nightmare/k8s/service.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-58
spec:
  type: LoadBalancer
```

#### Why This Is Wrong & Dangerous
Creates an expensive cloud load balancer for every individual service, bypassing centralized Ingress controllers, TLS termination, WAFs, and rate limits.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/service.yaml` & `k8s/overlays/prod/ingress.yaml`:
Uses internal `ClusterIP` services exposed through an Ingress controller with TLS certificates from `cert-manager`.

---

### AUDIT-59: Postgres Exposed via Public `LoadBalancer`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/service.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-59
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  type: LoadBalancer
  ports:
    - port: 5432
```

#### Why This Is Wrong & Dangerous
Provisions a public cloud load balancer directly attached to your database, exposing port 5432 to the entire internet for brute-force attacks and port scanning.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/postgres-statefulset.yaml`:
Uses a headless Service (`clusterIP: None`) accessible only inside the cluster via internal DNS.

---

### AUDIT-60: Postgres Deployed as a Bare `Pod`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/postgres-pod.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-60
apiVersion: v1
kind: Pod
metadata:
  name: postgres
```

#### Why This Is Wrong & Dangerous
A bare `Pod` is not managed by a controller (StatefulSet or Deployment). If the node running this pod crashes or undergoes maintenance, Kubernetes **will not reschedule** or recreate the database pod.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/postgres-statefulset.yaml`:
Managed via a `StatefulSet` with stable network identity and lifecycle management.

---

### AUDIT-61: Postgres Using Unpinned `latest` Tag
- **Severity**: High
- **Location**: `tiffin-nightmare/k8s/postgres-pod.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-61
image: postgres:latest
```

#### Why This Is Wrong & Dangerous
Causes unexpected major database upgrades and startup failures.

#### The Right Way (Pristine)
Pinned to `postgres:16.9-bookworm`.

---

### AUDIT-62: Postgres Running as Root
- **Severity**: High
- **Location**: `tiffin-nightmare/k8s/postgres-pod.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-62
# No securityContext on Postgres pod
```

#### Why This Is Wrong & Dangerous
Runs the database process as root.

#### The Right Way (Pristine)
Runs as non-root `runAsUser: 999`, dropping all Linux capabilities.

---

### AUDIT-63: emptyDir for Postgres Storage (Data Loss Guarantee 2)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/postgres-pod.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-63
volumeMounts:
  - name: data
    mountPath: /var/lib/postgresql/data
volumes:
  - name: data
    emptyDir: {}
```

#### Why This Is Wrong & Dangerous
**This is Data Loss Guarantee #2.** `emptyDir` volumes are temporary storage tied to the lifecycle of the pod. The moment the postgres pod is restarted, upgraded, or rescheduled, **all database files are deleted forever**.

#### The Right Way (Pristine)
In `tiffin-pristine/k8s/base/postgres-statefulset.yaml`:
```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi
```
Provisions persistent EBS/cloud block storage via `volumeClaimTemplates`.

---

### AUDIT-64: Committed Kubernetes Secret Manifest
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/secret.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-64
apiVersion: v1
kind: Secret
metadata:
  name: tiffin-secrets
```

#### Why This Is Wrong & Dangerous
Commits raw secret manifests to git.

#### The Right Way (Pristine)
Secrets are pulled at runtime from AWS Secrets Manager using `ExternalSecret` custom resources.

---

### AUDIT-65: Base64 Mistaken for Encryption
- **Severity**: Critical
- **Location**: `tiffin-nightmare/k8s/secret.yaml`

#### The Wrong Way (Nightmare)
```yaml
# AUDIT-65
data:
  DATABASE_URL: cG9zdGdyZXM6Ly90aWZmaW46VGlmZmluQDIwMjNAcG9zdGdyZXM6NTQzMi90aWZmaW4=
  ADMIN_PASSWORD: YWRtaW4=
  JWT_SECRET: c3VwZXJzZWNyZXQxMjM=
```

#### Why This Is Wrong & Dangerous
Base64 is an encoding scheme, **not** encryption. Anyone can decode it instantly:
```bash
echo "cG9zdGdyZXM6Ly90aWZmaW46VGlmZmluQDIwMjNAcG9zdGdyZXM6NTQzMi90aWZmaW4=" | base64 -d
# Output: postgres://tiffin:Tiffin@2023@postgres:5432/tiffin
```

#### The Right Way (Pristine)
Secrets are encrypted at rest with AWS KMS and never stored in git.

---

## Section F: Terraform & Infrastructure as Code

### AUDIT-66: AWS Access Key and Secret Hardcoded in Provider Block
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-66
provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAQYX7EXAMPLE4TIFF"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}
```

#### Why This Is Wrong & Dangerous
Hardcoding AWS root or IAM user access keys into `.tf` files exposes full cloud infrastructure access to anyone who can view the repository.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/providers.tf`:
```hcl
provider "aws" {
  region = var.aws_region
  # Credentials assumed via IAM roles or local environment variables (AWS_PROFILE)
}
```

---

### AUDIT-67: Missing `required_version` & Provider Constraints
- **Severity**: High
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-67
# No required_version or required_providers block
```

#### Why This Is Wrong & Dangerous
Different engineers running `terraform apply` with different CLI or provider versions will generate incompatible state files and trigger breaking resource changes.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/versions.tf`:
```hcl
terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.99"
    }
  }
}
```

---

### AUDIT-68: Missing Remote Backend (Local State)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-68
# No backend defined; state stored locally
```

#### Why This Is Wrong & Dangerous
State files stored locally cannot be locked. Two engineers running Terraform simultaneously will corrupt the state file or delete resources created by the other.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket       = "tiffin-tfstate-ap-south-1"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
```
State is encrypted in S3 with state locking enabled.

---

### AUDIT-69: Inbound SSH Port 22 Open to `0.0.0.0/0`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-69
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

#### Why This Is Wrong & Dangerous
Exposes SSH ports to constant automated brute-force attacks from the internet.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/network.tf`:
Access is restricted strictly to verified office CIDR blocks, or managed via AWS Systems Manager (SSM) Session Manager with zero open inbound ports.

---

### AUDIT-70: Database Port 5432 & All TCP Ports Open to `0.0.0.0/0`
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-70
ingress {
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
ingress {
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

#### Why This Is Wrong & Dangerous
Opens every single TCP port on your database and servers to the entire world.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
```hcl
resource "aws_security_group_rule" "rds_ingress_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.rds.id
}
```
Inbound traffic on port 5432 is permitted **only** from the specific application security group.

---

### AUDIT-71: Hardcoded Master Database Password in HCL
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-71
password = "Tiffin@2023"
```

#### Why This Is Wrong & Dangerous
Hardcoding passwords in `.tf` files exposes the database credentials in version control and state logs.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
Uses `random_password` resource to generate a cryptographic password, automatically storing it directly in **AWS Secrets Manager**.

---

### AUDIT-72: RDS publicly_accessible Set to True
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-72
publicly_accessible = true
```

#### Why This Is Wrong & Dangerous
Assigns a public IPv4 address to the database instance, allowing public internet routing to the database.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
`publicly_accessible = false` and deployed in private, non-routable subnets.

---

### AUDIT-73: Unencrypted Storage (storage_encrypted Set to False)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-73
storage_encrypted = false
```

#### Why This Is Wrong & Dangerous
Data on disk and snapshots are stored in plaintext. In RDS, **encryption cannot be enabled in-place on an existing unencrypted database**; fixing this requires creating a new instance and migrating data.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
```hcl
storage_encrypted = true
kms_key_id        = aws_kms_key.tiffin.arn
```
Encrypted at rest using a dedicated customer-managed KMS key.

---

### AUDIT-74: Automated Backups Disabled (Data Loss Guarantee 3)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-74
backup_retention_period = 0
```

#### Why This Is Wrong & Dangerous
**This is Data Loss Guarantee #3.** Setting retention to 0 completely disables automated daily backups and Point-In-Time Recovery (PITR) in Amazon RDS.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
```hcl
backup_retention_period   = var.environment == "prod" ? 14 : 7
backup_window             = "18:00-19:00" # Asia/Kathmandu night window
```

---

### AUDIT-75: skip_final_snapshot Set to True (Data Loss Guarantee 4)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-75
skip_final_snapshot = true
```

#### Why This Is Wrong & Dangerous
**This is Data Loss Guarantee #4.** If someone runs `terraform destroy` or deletes the RDS instance, AWS destroys the database immediately without taking a final snapshot. Combined with `backup_retention_period = 0`, all data is gone instantly.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
```hcl
skip_final_snapshot       = var.environment != "prod"
final_snapshot_identifier = "tiffin-${var.environment}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"
```

---

### AUDIT-76: RDS deletion_protection Set to False
- **Severity**: High
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-76
deletion_protection = false
```

#### Why This Is Wrong & Dangerous
Allows accidental deletion of production databases via a single misconfigured API or Terraform call.

#### The Right Way (Pristine)
`deletion_protection = true` on production databases.

---

### AUDIT-77: Single-AZ Deployment in Production
- **Severity**: High
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-77
multi_az = false
```

#### Why This Is Wrong & Dangerous
If the AWS Availability Zone experiences an outage, the database goes down and cannot fail over.

#### The Right Way (Pristine)
`multi_az = true` in production, providing synchronous standby replication across separate AZs.

---

### AUDIT-78: Missing Monitoring & Log Exports
- **Severity**: Medium
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-78
# No monitoring or log exports enabled
```

#### Why This Is Wrong & Dangerous
Database slow query logs, crash logs, and OS CPU/memory metrics are not recorded.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/database.tf`:
Enables Enhanced Monitoring (`monitoring_interval = 60`), Performance Insights, and CloudWatch log exports for `postgresql` and `upgrade`.

---

### AUDIT-79: S3 Public Access Block Disabled
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-79
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
```

#### Why This Is Wrong & Dangerous
Explicitly disables every S3 public access protection, allowing public read and write access to uploaded customer files.

#### The Right Way (Pristine)
In `tiffin-pristine/terraform/backups.tf`:
All four public access block settings are set to `true`.

---

### AUDIT-80: Plaintext Password Output
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/main.tf`

#### The Wrong Way (Nightmare)
```hcl
# AUDIT-80
output "db_password" {
  value = aws_db_instance.tiffin.password
}
```

#### Why This Is Wrong & Dangerous
Prints the raw database password to terminal screens and CI execution logs.

#### The Right Way (Pristine)
Sensitive outputs are removed or marked with `sensitive = true`, pointing consumers to Secrets Manager instead.

---

### AUDIT-81: Terraform State in Git with "Take Newer on Conflict"
- **Severity**: Critical
- **Location**: `tiffin-nightmare/terraform/NOTES.txt`

#### The Wrong Way (Nightmare)
```
# AUDIT-81
run terraform apply from your laptop. state file is in the repo so we all
share it. if you get a conflict just take whichever version is newer and
commit that. dont run apply at the same time as someone else.
```

#### Why This Is Wrong & Dangerous
1. **Plaintext Secrets in Git**: `terraform.tfstate` contains unencrypted values for all created resources (including database passwords and private keys).
2. **State Corruption**: Resolving git conflicts by "taking the newer state" discards resources tracked in the older state, causing Terraform to lose track of live cloud infrastructure.
3. **No State Locking**: Applying from laptops concurrently causes race conditions.

#### The Right Way (Pristine)
State is stored in a versioned, encrypted S3 bucket with native state locking (`use_lockfile = true`), and applied exclusively through automated pipelines.

---

## Section G: Disaster Recovery & Backups

### AUDIT-82: "Call Bikash" Runbook
- **Severity**: High
- **Location**: `tiffin-nightmare/docs/runbook.md`

#### The Wrong Way (Nightmare)
```markdown
# AUDIT-82
1. restart the pod
2. if that doesnt work restart the db pod
3. if that doesnt work call bikash
```

#### Why This Is Wrong & Dangerous
Tribal knowledge is not a disaster recovery strategy. When the author leaves the company, operations grind to a halt.

#### The Right Way (Pristine)
In `tiffin-pristine/docs/RUNBOOK-dr-drill.md`:
An actionable, step-by-step triage guide with concrete commands, symptom-to-cause matrices, rollback steps, and clear verification checklists.

---

### AUDIT-83: Missing Restore Procedure (`TODO`)
- **Severity**: Critical
- **Location**: `tiffin-nightmare/docs/runbook.md`

#### The Wrong Way (Nightmare)
```markdown
# AUDIT-83
TODO
```

#### Why This Is Wrong & Dangerous
An untested backup is not a backup. Having no restore procedure guarantees hours of downtime while engineers try to figure out how to restore data under extreme incident pressure.

#### The Right Way (Pristine)
In `tiffin-pristine/scripts/restore.sh` & `docs/RUNBOOK-dr-drill.md`:
- Automated restore script (`restore.sh`) with SHA-256 checksum verification.
- Enforces restoring to a scratch database first to validate row counts before promoting.
- Documented RTO (Recovery Time Objective: < 60 min) and RPO (Recovery Point Objective: < 24h dump / < 5min PITR).

---

## Master Defect Index

| ID | Domain | Defect Summary | Severity | Nightmare Location | Pristine Fix Location |
|---|---|---|---|---|---|
| [**01**](#audit-01-package-lockjson-is-gitignored) | Supply Chain | `package-lock.json` gitignored | High | `.gitignore` | `package-lock.json` committed |
| [**02**](#audit-02-env-committed-to-git-with-live-credentials) | Secrets | `.env` committed with live keys | **Critical** | `.env` | `.env.example`, AWS Secrets Manager |
| [**03**](#audit-03-wildcard-cors-with-credentials) | Security | Wildcard CORS with credentials | High | `src/index.js` | `src/app.js` (explicit origin allowlist) |
| [**04**](#audit-04-static-health-endpoint-serving-both-liveness-readiness) | Reliability | Static `/health` (liveness/readiness unified) | High | `src/index.js` | `src/routes/health.js` (`/healthz` vs `/readyz`) |
| [**05**](#audit-05-stack-traces-leaked-in-error-responses) | Security | `err.stack` returned to client | Medium | `src/index.js` | `src/app.js` (central error handler) |
| [**06**](#audit-06-sql-injection-via-string-concatenation) | Security | SQL Injection via string concatenation | **Critical** | `src/index.js` | `src/routes/orders.js` (parameterized SQL) |
| [**07**](#audit-07-missing-input-validation-on-request-bodies) | Security | Missing request body validation | High | `src/index.js` | `src/schemas.js` (Zod validation) |
| [**08**](#audit-08-plaintext-pii-phone-numbers-logged) | Security | Plaintext customer phone numbers logged | High | `src/index.js` | `src/logger.js` (Pino redaction) |
| [**09**](#audit-09-md5-hashing-non-constant-time-password-comparison) | Security | MD5 password hashing & timing attack | High | `src/index.js` | Password hashing & constant-time check |
| [**10**](#audit-10-debugenv-route-exposing-secrets) | Security | `/debug/env` exposing environment secrets | **Critical** | `src/index.js` | Route removed; validated in `config.js` |
| [**11**](#audit-11-missing-graceful-sigterm-handling) | Reliability | Missing graceful SIGTERM handling | Medium | `src/index.js` | `src/server.js` (`server.close`, drain pool) |
| [**12**](#audit-12-unstructured-logging-without-request-ids) | Observability| Unstructured `console.log` | Medium | `src/index.js` | `src/logger.js` (JSON Pino with request ID) |
| [**13**](#audit-13-missing-metrics-distributed-tracing) | Observability| Missing `/metrics` & distributed tracing | Medium | `src/index.js` | `src/metrics.js`, `src/tracing.js` |
| [**14**](#audit-14-hardcoded-fallback-connection-string-ssl-false) | Security | Hardcoded fallback DB string & `ssl: false` | High | `src/db.js` | `src/config.js`, `src/db.js` (enforced SSL) |
| [**15**](#audit-15-postgres-pool-error-handler-fails-silently) | Reliability | DB pool error handler silent | Medium | `src/db.js` | `src/db.js` (`logger.fatal`) |
| [**16**](#audit-16-query-wrapper-accepts-params-and-discards-them) | Security | `query` wrapper discards `params` | **Critical** | `src/db.js` | `src/db.js` (passes params to driver) |
| [**17**](#audit-17-tautological-smoke-test) | Quality | Tautological `1 + 1 === 2` smoke test | High | `test/smoke.test.js` | `test/unit/`, `test/integration/` |
| [**18**](#audit-18-unpinned-from-nodelatest-base-image) | Docker | Unpinned `FROM node:latest` | High | `Dockerfile` | `node:22.17-bookworm-slim` |
| [**19**](#audit-19-single-stage-build-shipping-build-artifacts) | Docker | Single-stage image shipping dev tools | Medium | `Dockerfile` | Multi-stage build (`deps`, `test`, `runtime`) |
| [**20**](#audit-20-copy-before-npm-install) | Docker | `COPY . .` before `npm install` | High | `Dockerfile` | Ordered copies + `.dockerignore` |
| [**21**](#audit-21-npm-install-instead-of-npm-ci) | Docker | `npm install` without lockfile | High | `Dockerfile` | `npm ci --ignore-scripts` |
| [**22**](#audit-22-installing-debugging-network-attack-tools) | Docker | Attack tools installed in container | High | `Dockerfile` | Minimal runtime; only `dumb-init` |
| [**23**](#audit-23-production-connection-string-baked-into-image-env) | Docker | DB password baked into image ENV | **Critical** | `Dockerfile` | Secrets injected at runtime |
| [**24**](#audit-24-missing-container-healthcheck-instruction) | Docker | Missing container `HEALTHCHECK` | Low | `Dockerfile` | `HEALTHCHECK` with `/healthz` |
| [**25**](#audit-25-shell-form-cmd-running-as-root) | Docker | Shell-form `CMD` running as root | High | `Dockerfile` | `USER node`, `dumb-init`, exec-form |
| [**26**](#audit-26-obsolete-compose-version-2) | Docker | Obsolete Compose `version: "2"` | Low | `docker-compose.yml` | `name: tiffin` |
| [**27**](#audit-27-app-bound-to-00003000) | Docker | App published on `0.0.0.0:3000` | Medium | `docker-compose.yml` | `127.0.0.1:3000:3000` |
| [**28**](#audit-28-bind-mounting-entire-host-tree-into-container) | Docker | Bind-mount host source over `/app` | Medium | `docker-compose.yml` | Isolated container image target |
| [**29**](#audit-29-sleep-10-for-database-dependency-management) | Docker | `sleep 10` for DB startup | Medium | `docker-compose.yml` | `depends_on: condition: service_healthy` |
| [**30**](#audit-30-postgres-unpinned-latest-tag) | Docker | `postgres:latest` tag | High | `docker-compose.yml` | Pinned `postgres:16.9-bookworm` |
| [**31**](#audit-31-postgres-published-on-54325432-to-lan) | Docker | Postgres port open to LAN `5432:5432` | High | `docker-compose.yml` | Bound to `127.0.0.1:5432:5432` |
| [**32**](#audit-32-hardcoded-password-in-compose) | Docker | Hardcoded password in compose | High | `docker-compose.yml` | `${PGPASSWORD:?}` from `.env` |
| [**33**](#audit-33-missing-database-storage-volume-data-loss-guarantee-1) | DR / Data | No volume mounted for database | **Critical** | `docker-compose.yml` | Named volume `pgdata` |
| [**34**](#audit-34-on-push-without-branch-filtering) | CI/CD | `on: push` without branch filter | Medium | `.github/workflows/ci.yml` | Branch filters (`main`) |
| [**35**](#audit-35-missing-permissions-block) | CI/CD | Missing `permissions:` block | High | `.github/workflows/ci.yml` | `permissions: contents: read` |
| [**36**](#audit-36-mutable-action-reference-at-master) | CI/CD | Mutable `@master` action reference | High | `.github/workflows/ci.yml` | SHA pinned actions |
| [**37**](#audit-37-npm-install-in-ci-without-dependency-cache) | CI/CD | `npm install` without caching in CI | Low | `.github/workflows/ci.yml` | `npm ci` + `cache: npm` |
| [**38**](#audit-38-continue-on-error-true-on-test-step) | CI/CD | `continue-on-error: true` on tests | High | `.github/workflows/ci.yml` | Removed; tests gate builds |
| [**39**](#audit-39-database-secret-echoed-into-ci-logs) | CI/CD | Secrets echoed to CI logs & `::debug::` | **Critical** | `.github/workflows/ci.yml` | Secrets never printed |
| [**40**](#audit-40-pushing-unscanned-latest-tag-on-every-commit) | CI/CD | Pushes `:latest` without CVE scan | High | `.github/workflows/ci.yml` | Digest tags + Trivy scan + Cosign |
| [**41**](#audit-41-missing-concurrency-control) | CI/CD | Missing `concurrency` cancellation | Low | `.github/workflows/ci.yml` | `concurrency: cancel-in-progress: true` |
| [**42**](#audit-42-arbitrary-code-execution-via-pullrequesttarget) | CI/CD | Arbitrary code execution via `pull_request_target` | **Critical** | `.github/workflows/deploy.yml` | Tag-triggered deploy; `pull_request` for CI |
| [**43**](#audit-43-missing-environment-protection-approval-gates) | CI/CD | Missing environment approval gate | High | `.github/workflows/deploy.yml` | `environment: production` approval |
| [**44**](#audit-44-checking-out-mutable-branch-ref) | CI/CD | Checks out mutable `head.ref` | High | `.github/workflows/deploy.yml` | Immutable commit SHA |
| [**45**](#audit-45-long-lived-static-aws-credentials-in-ci-secrets) | CI/CD | Long-lived static AWS keys in secrets | **Critical** | `.github/workflows/deploy.yml` | AWS OIDC Role Assumption |
| [**46**](#audit-46-kubeconfig-stored-in-ci-and-given-chmod-777) | CI/CD | Kubeconfig in CI with `chmod 777` | **Critical** | `.github/workflows/deploy.yml` | GitOps (Argo CD); no cluster secrets in CI |
| [**47**](#audit-47-blind-kubectl-apply-and-rollout-restart) | CI/CD | Blind `kubectl apply` & `rollout restart` | High | `.github/workflows/deploy.yml` | GitOps sync with manifest validation |
| [**48**](#audit-48-deploys-to-default-namespace-without-psa) | K8s | Deploys to `default` namespace without PSA | Medium | `k8s/deployment.yaml` | `namespace.yaml` with PSA Restricted |
| [**49**](#audit-49-single-replica-replicas-1) | K8s | Single replica (`replicas: 1`) | High | `k8s/deployment.yaml` | `replicas: 3` + `pdb.yaml` + HPA |
| [**50**](#audit-50-missing-deployment-strategy) | K8s | Missing deployment rolling strategy | Medium | `k8s/deployment.yaml` | `maxSurge: 1, maxUnavailable: 0` |
| [**51**](#audit-51-hostnetwork-true) | K8s | `hostNetwork: true` | **Critical** | `k8s/deployment.yaml` | Removed; overlay networking |
| [**52**](#audit-52-unpinned-latest-image-tag-with-always-pull-policy) | K8s | `image: :latest` + `imagePullPolicy: Always` | High | `k8s/deployment.yaml` | Pinned image SHA / digests |
| [**53**](#audit-53-high-privilege-security-context-root-and-privileged) | K8s | `privileged: true`, `runAsUser: 0` | **Critical** | `k8s/deployment.yaml` | Non-root `runAsUser: 1000`, drop ALL caps |
| [**54**](#audit-54-plaintext-secrets-in-manifest-environment-variables) | K8s | Secrets hardcoded in deployment env | **Critical** | `k8s/deployment.yaml` | External Secrets Operator |
| [**55**](#audit-55-hostpath-mounted-into-container) | K8s | `hostPath: /` mounted into container | **Critical** | `k8s/deployment.yaml` | Removed; `readOnlyRootFilesystem: true` |
| [**56**](#audit-56-missing-resource-requests-and-limits) | K8s | Missing resource requests & limits | High | `k8s/deployment.yaml` | CPU requests + memory limits |
| [**57**](#audit-57-missing-liveness-readiness-startup-probes) | K8s | Missing liveness & readiness probes | High | `k8s/deployment.yaml` | Liveness, readiness, and startup probes |
| [**58**](#audit-58-api-service-type-loadbalancer) | K8s | Service type `LoadBalancer` for app | Medium | `k8s/service.yaml` | `ClusterIP` + Ingress + TLS |
| [**59**](#audit-59-postgres-exposed-via-public-loadbalancer) | K8s | Postgres exposed via `LoadBalancer` | **Critical** | `k8s/service.yaml` | Headless Service `clusterIP: None` |
| [**60**](#audit-60-postgres-deployed-as-a-bare-pod) | K8s | Postgres as bare unmanaged `Pod` | **Critical** | `k8s/postgres-pod.yaml` | Managed `StatefulSet` |
| [**61**](#audit-61-postgres-using-unpinned-latest-tag) | K8s | Postgres unpinned `:latest` tag | High | `k8s/postgres-pod.yaml` | Pinned `postgres:16.9-bookworm` |
| [**62**](#audit-62-postgres-running-as-root) | K8s | Postgres running as root | High | `k8s/postgres-pod.yaml` | `runAsUser: 999`, drop capabilities |
| [**63**](#audit-63-emptydir-for-postgres-storage-data-loss-guarantee-2) | DR / Data | `emptyDir` for Postgres data | **Critical** | `k8s/postgres-pod.yaml` | `volumeClaimTemplates` (PersistentVolume) |
| [**64**](#audit-64-committed-kubernetes-secret-manifest) | K8s | Secret manifest committed to git | **Critical** | `k8s/secret.yaml` | External Secrets Operator |
| [**65**](#audit-65-base64-mistaken-for-encryption) | K8s | Base64 mistaken for encryption | **Critical** | `k8s/secret.yaml` | AWS KMS encryption at rest |
| [**66**](#audit-66-aws-access-key-and-secret-hardcoded-in-provider-block) | Terraform | Hardcoded AWS keys in provider block | **Critical** | `terraform/main.tf` | IAM roles / OIDC |
| [**67**](#audit-67-missing-requiredversion-provider-constraints) | Terraform | Missing `required_version` constraints | High | `terraform/main.tf` | `versions.tf` version pinning |
| [**68**](#audit-68-missing-remote-backend-local-state) | Terraform | Missing remote backend (local state) | **Critical** | `terraform/main.tf` | S3 remote backend with locking |
| [**69**](#audit-69-inbound-ssh-port-22-open-to-00000) | Terraform | Inbound SSH open to `0.0.0.0/0` | **Critical** | `terraform/main.tf` | Restricted CIDR / SSM Session Manager |
| [**70**](#audit-70-database-port-5432-all-tcp-ports-open-to-00000) | Terraform | Postgres port open to `0.0.0.0/0` | **Critical** | `terraform/main.tf` | Security Group referencing rules |
| [**71**](#audit-71-hardcoded-master-database-password-in-hcl) | Terraform | Database password hardcoded in HCL | **Critical** | `terraform/main.tf` | `random_password` + Secrets Manager |
| [**72**](#audit-72-rds-publiclyaccessible-set-to-true) | Terraform | `publicly_accessible = true` on RDS | **Critical** | `terraform/main.tf` | `false` + private subnets |
| [**73**](#audit-73-unencrypted-storage-storageencrypted-set-to-false) | Terraform | Storage unencrypted (`storage_encrypted = false`) | **Critical** | `terraform/main.tf` | KMS customer-managed key encryption |
| [**74**](#audit-74-automated-backups-disabled-data-loss-guarantee-3) | DR / Data | `backup_retention_period = 0` | **Critical** | `terraform/main.tf` | 14-day retention + automated snapshots |
| [**75**](#audit-75-skipfinalsnapshot-set-to-true-data-loss-guarantee-4) | DR / Data | `skip_final_snapshot = true` | **Critical** | `terraform/main.tf` | `false` in prod + timestamped snapshots |
| [**76**](#audit-76-rds-deletionprotection-set-to-false) | Terraform | `deletion_protection = false` | High | `terraform/main.tf` | `true` on production RDS |
| [**77**](#audit-77-single-az-deployment-in-production) | Terraform | `multi_az = false` in production | High | `terraform/main.tf` | `multi_az = true` |
| [**78**](#audit-78-missing-monitoring-log-exports) | Observability| Missing DB monitoring & log exports | Medium | `terraform/main.tf` | Enhanced Monitoring + CloudWatch exports |
| [**79**](#audit-79-s3-public-access-block-disabled) | Terraform | S3 public access block disabled | **Critical** | `terraform/main.tf` | All 4 public access blocks enabled |
| [**80**](#audit-80-plaintext-password-output) | Terraform | `output "db_password"` leaking secret | **Critical** | `terraform/main.tf` | Removed / `sensitive = true` |
| [**81**](#audit-81-terraform-state-in-git-with-take-newer-on-conflict) | Terraform | State in git; "take newer on conflict" | **Critical** | `terraform/NOTES.txt` | S3 versioned backend + state locking |
| [**82**](#audit-82-call-bikash-runbook) | DR / Ops | Runbook is "call Bikash" | High | `docs/runbook.md` | `RUNBOOK-dr-drill.md` actionable triage |
| [**83**](#audit-83-missing-restore-procedure-todo) | DR / Ops | Restore procedure is `TODO` | **Critical** | `docs/runbook.md` | `restore.sh` with checksum validation & drill |
