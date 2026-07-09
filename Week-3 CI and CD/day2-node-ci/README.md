# Day 2 — A real CI pipeline

A one-file library (`src/slug.js`) with real tests (`__tests__/slug.test.js`). The point
is not the code — it is the pipeline that guards it.

Local commands (run these before you push, every time):

```bash
npm install
npm run lint
npm test
npm run test:coverage
```

The workflow at `../.github/workflows/day2-ci.yml` runs exactly those commands on GitHub,
plus dependency caching and a coverage artifact. Break a test on purpose, push, and watch
the red X appear — that red X is the whole point of CI.
