# Day 1 — Hello, Actions

The smallest possible thing that is still a real GitHub Actions workflow.

- `greet.js` — prints a greeting, reads `GREET_NAME` from the environment.
- `Dockerfile` — packages `greet.js` into an image (used in today's Docker exercise).

The workflow lives at `../.github/workflows/day1-hello.yml`. Open it, read every line,
and match each key to the anatomy diagram in the lesson: **event → job → runner → steps**.

Run it locally to prove it works before you trust CI:

```bash
node greet.js
GREET_NAME=Kathmandu node greet.js
```
