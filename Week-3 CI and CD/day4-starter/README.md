# Day 4 — Matrices, service containers, artifacts

A link shortener backed by **Postgres** (persistence) and **Redis** (cache) — the same
shape as the ShortLink capstone, shrunk to fit one lesson.

- `__tests__/shorten.test.js` — pure logic, runs anywhere.
- `__tests__/store.integration.test.js` — needs a database and a cache.

Run unit tests anywhere:

```bash
npm run test:unit
```

Run integration tests locally only if you provide the services yourself:

```bash
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres
export REDIS_URL=redis://localhost:6379
npm run test:integration
```

In CI you provide nothing — the workflow at `../.github/workflows/day4-integration.yml`
starts Postgres and Redis as **service containers**, runs the whole suite across a
**matrix** of Node versions, and uploads the results as an artifact.
