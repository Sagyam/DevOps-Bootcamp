# Day 4 — Matrices, service containers, and reuse

**Mini-project:** `day4-integration/` · **Starter:** `day4-starter.zip`

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | The problem: some tests need real infrastructure | 15 min |
| 2 | Service containers: Postgres + Redis beside the job | 35 min |
| 3 | Matrix builds: same job, many versions | 25 min |
| 4 | Composite action: stop repeating setup | 25 min |
| 5 | Artifacts per matrix cell | 15 min |
| 6 | Exercises (incl. Docker) | 40 min |

Objectives: students run integration tests against Postgres and Redis service containers,
fan a job out over a version matrix, and factor repeated steps into a reusable composite
action.

---

## The problem

Yesterday's tests were pure logic — no database, no network. But `day4-integration/` is a
link shortener backed by **Postgres** and **Redis** (the same shape as the ShortLink
capstone). Its interesting bugs live exactly where code meets the database and the cache.
You can't test that with mocks and feel safe; you need a *real* Postgres and a *real* Redis.

But you also don't want students hand-installing Postgres on the shared VM just to run a
test suite. And once you have a working suite, you want to know it works on the Node version
production uses — not only the one on your machine.

GitHub Actions answers both: **service containers** give each job throwaway real
infrastructure, and a **matrix** runs the whole job across several versions at once.

## What you'll build today

An integration pipeline that starts Postgres and Redis as containers alongside the job,
runs unit tests plus integration tests that actually read and write those services, across
a matrix of Node 20 and 22, and uploads a log per matrix cell. Reference:
`.github/workflows/day4-integration.yml`.

## Split your tests honestly

Look at the project:

- `__tests__/shorten.test.js` — pure logic, runs anywhere, instantly.
- `__tests__/store.integration.test.js` — needs `DATABASE_URL` and `REDIS_URL`; it skips
  itself if they're absent.

That split is a real-world habit: fast unit tests give quick feedback; slower integration
tests give confidence. CI runs both; your laptop can run just the fast ones.

## New tools

**Service containers.** Under a job, `services:` starts Docker containers that live as long
as the job does. The job reaches them on `localhost` at the mapped port:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_PASSWORD: postgres
    ports:
      - 5432:5432
    options: >-
      --health-cmd "pg_isready -U postgres"
      --health-interval 10s --health-timeout 5s --health-retries 5
```

The `--health-cmd` options are the important part: steps don't start until Postgres reports
healthy, so you never race a database that isn't ready yet. This is the same health-check
idea from your Docker week, now gating the pipeline. Redis is configured the same way with
`redis-cli ping`. The job then just sets `DATABASE_URL` / `REDIS_URL` to `localhost` and the
app connects as if the services were always there.

**Matrix.** One job definition, run once per value:

```yaml
strategy:
  fail-fast: false
  matrix:
    node-version: ['20', '22']
```

You get two parallel runs. `fail-fast: false` means one failing version still lets the
other finish, so you see the whole picture instead of the first failure only. Anything the
matrix produces (like an uploaded log) must include `${{ matrix.node-version }}` in its
name, or the two cells overwrite each other.

**Composite action.** By now, "checkout → setup-node → npm ci" is copy-pasted everywhere.
The repo has a local composite action at `.github/actions/setup-node-project/` that bundles
those into one reusable step:

```yaml
- uses: ./.github/actions/setup-node-project
  with:
    node-version: ${{ matrix.node-version }}
    working-directory: day4-integration
```

A composite action is "a reusable *set of steps* that lives in your repo." When your setup
changes, you edit it once. (Its bigger sibling, the **reusable workflow**, factors out
whole jobs — see the exercises.)

## Exercises

1. **Watch the services come up.** In a run, expand the Postgres service logs and find the
   "database system is ready to accept connections" line. Note that the integration tests
   ran (not skipped) because the job set `DATABASE_URL`.

2. **Grow the matrix.** Add Node `18` to the matrix. Confirm three parallel jobs appear.
   Then remove it and discuss: how many versions is worth the runner minutes?

3. **Make one cell fail intentionally.** Add a test that only fails on Node 20 (e.g. relies
   on a Node 22 feature). Confirm `fail-fast: false` lets the Node 22 cell still pass, and
   that the run is marked failed overall.

4. **Docker exercise — service containers vs `docker compose`.** You've used
   `docker compose` to run Postgres + Redis + app locally. Write a short comparison: when
   would you reach for service containers (CI) vs a compose file (local dev)? Then run the
   app's own image against the CI-style services locally to feel the difference.

5. **Reusable workflow (stretch).** Convert the "unit + integration" job into a *reusable
   workflow* (`on: workflow_call`) in a new file, and have `day4-integration.yml` call it.
   Note how inputs and secrets pass across the boundary. This is the pattern large repos use
   to avoid duplicating pipelines.

## Common pitfalls

- Integration tests skip in CI → you didn't set `DATABASE_URL`/`REDIS_URL` at the job or
  step level, so the app has nothing to connect to.
- Connection refused → missing or wrong `ports:` mapping, or steps ran before the service
  was healthy (add/adjust the health-check options).
- Both matrix cells fight over one artifact name → include `${{ matrix.node-version }}` in
  the artifact `name:`.
- `uses: ./.github/actions/...` "not found" → the composite action needs `checkout` to run
  first, so the files exist on the runner.

## Recap

Real tests need real infrastructure; service containers provide it, disposably, per job.
Matrices prove your code across the versions that matter. Composite actions kill the
copy-paste. Tomorrow: secrets, environments, and actually deploying.
