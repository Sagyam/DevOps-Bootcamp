# Day 6 — Capstone: one pipeline, everything you've learned

**Mini-project:** `day6-capstone/` · **Starter:** `day6-starter.zip`

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | Tour the app; read the spec together | 20 min |
| 2 | Students build the pipeline from a blank file | 90 min |
| 3 | Compare against the reference; debug real runs | 40 min |
| 4 | Review, rubric walkthrough, retro | 30 min |

Objectives: students independently assemble a complete CI/CD pipeline — lint, matrixed
integration tests against a service container, image build/push, and a gated deploy —
reusing the composite action and every pattern from the week.

---

## The problem

You've learned each piece in isolation: path filters (Day 1), lint/test/cache/artifacts
(Day 2), Docker build/push (Day 3), service containers/matrices/composite actions (Day 4),
secrets/environments/deploy (Day 5). A real pipeline is all of them in one file, wired so
each stage gates the next. Today you build that, mostly on your own.

## The app you're shipping

`day6-capstone/` is a **Task API** — Node + Postgres, with input validation, unit tests, a
full HTTP integration test, and a multi-stage `Dockerfile`. **The application is done.**
Read it, run it locally, then leave it alone. Your deliverable is the pipeline.

```bash
cd day6-capstone
npm install
npm run lint
npm run test:unit
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres
npm run test:integration
```

## Your task: write `.github/workflows/day6-capstone.yml` from scratch

Meet this spec. A reference solution ships in the repo at the same path — **write yours in a
different filename first (e.g. `day6-mine.yml`), then compare.**

Your pipeline must:

1. **Trigger only** on changes to `day6-capstone/**` (and its own file). Path filters, as
   every day.
2. **`quality` job** — use the composite action `./.github/actions/setup-node-project`, then
   run `lint` and `test:unit`. Fast feedback, no services.
3. **`integration` job** — `needs: quality`. Run `test:integration` across a **matrix** of
   Node 20 and 22, against a **Postgres service container** with a health check.
4. **`build` job** — `needs: integration`, skipped on pull requests. Build the multi-stage
   image and push to GHCR tagged by commit SHA, with layer caching. Set the right
   `permissions`.
5. **`deploy` job** — `needs: build`. Deploy over SSH through a `production` **environment**.
   Pull the SHA-tagged image and restart the container.
6. Add **`concurrency`** so overlapping runs on the same ref cancel the older one.

## Grading rubric (share with students up front)

| Criterion | What "done" looks like |
|-----------|------------------------|
| Scoping | Workflow runs only when `day6-capstone/**` changes |
| Staging & gating | `quality → integration → build → deploy` via `needs`; deploy never runs before tests |
| Service + matrix | Integration tests pass against Postgres on both Node 20 and 22 |
| Reuse | Setup done via the composite action, not copy-pasted steps |
| Image | SHA-tagged image appears in GHCR, built from the multi-stage Dockerfile with caching |
| Secrets & env | Deploy uses repository secrets and a `production` environment; nothing secret in the file |
| Safety | `permissions` are least-privilege; `concurrency` prevents overlapping deploys |
| Green run | An end-to-end run on `main` is green through deploy (or blocked only at the approval gate) |

## Working through failure (this is the lesson)

Expect red runs. That's the exercise. Practise the loop you've used all week:

- Read the **first** failing step, not the last line of noise.
- Reproduce locally where you can (`npm run lint`, `npm run test:integration` with a local
  Postgres).
- For infra failures, check service **health checks** and env vars before blaming code.
- For push/deploy failures, check `permissions`, secrets, and whether you're on a PR (builds
  don't push on PRs by design).

## Stretch goals

1. **Reusable workflow.** Extract `quality` + `integration` into a `workflow_call` file and
   call it, so another project in the repo could reuse the exact test pipeline.
2. **PR vs main behaviour.** Make PRs run tests only; make `main` run the full build+deploy.
   (You already have the `if:` and `needs` tools for this.)
3. **Deploy summary.** Use `$GITHUB_STEP_SUMMARY` to write which image/version deployed, so
   the run page shows a human-readable record.
4. **Docker exercise — full local dry run.** Before trusting CI, reproduce the whole thing
   on the VM with `docker compose`: Postgres + the app image, run the integration tests
   against it, then deploy that same image. Prove local and CI agree.

## Where to go next (point students onward)

- **Self-hosted runners** — when you need your own hardware, GPUs, or private-network access.
- **OIDC to cloud providers** — deploy to AWS/Azure/GCP with short-lived tokens instead of
  long-lived secrets (a natural next step given your Azure certification track).
- **Dependency and image scanning** — Dependabot, Trivy, or CodeQL as pipeline stages.
- **Environments per stage** — `staging` then `production`, each with its own gate.

## Recap

The capstone is the week made whole: one path-scoped pipeline that lints, tests across a
matrix against real infrastructure, builds and pushes a traceable image, and deploys behind
a human gate — reusing shared building blocks and refusing to ship anything that failed a
check. That is CI/CD.
