# Day 6 — Capstone: the whole pipeline

A **Task API** (Node + Postgres) with validation, unit tests, integration tests, and a
multi-stage `Dockerfile`. The application is finished. **Your job is the pipeline.**

## The app

```bash
npm install
npm run lint
npm run test:unit

# Integration tests need a database:
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres
npm run test:integration

# Or run it for real:
docker build -t day6-capstone .
docker run --rm -e DATABASE_URL=... -p 3000:3000 day6-capstone
curl -X POST localhost:3000/tasks -d '{"title":"hello"}'
curl localhost:3000/tasks
```

## Your pipeline must

1. Run **only** when `day6-capstone/**` changes (path filter — same as every day).
2. **Lint**, then run **unit tests**.
3. Run **integration tests** against a **Postgres service container**, across a **matrix**
   of Node 20 and 22.
4. Use the repo's **composite action** (`./.github/actions/setup-node-project`) for setup.
5. **Build and push** the image to GHCR, tagged by commit SHA, with **layer caching**.
6. **Deploy** through a `production` **environment** — only after tests and build pass.
7. Use `concurrency` so two deploys never overlap.

A complete reference pipeline ships at `../.github/workflows/day6-capstone.yml`. Try to
write yours from a blank file first; open the reference only to compare.
