# Day 2 — A real CI pipeline: lint, test, cache, artifacts

**Mini-project:** `day2-node-ci/` · **Starter:** `day2-starter.zip`

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | Recap Day 1; the problem: "tests exist but nobody runs them" | 15 min |
| 2 | Marketplace actions: `checkout`, `setup-node` | 25 min |
| 3 | Dependency caching — why `npm ci`, why cache | 30 min |
| 4 | Lint + test + coverage as pipeline stages | 30 min |
| 5 | Artifacts; branch protection as the payoff | 20 min |
| 6 | Exercises (incl. Docker) | 40 min |

Objectives: students build a multi-step CI job that installs, lints, and tests a real
project with caching, uploads an artifact, and understands why a failing job should block a
merge.

---

## The problem

Yesterday's workflow just echoed things. Today's project, `day2-node-ci/`, has actual code
(`src/slug.js`) and actual tests (`__tests__/slug.test.js`). Locally you can run
`npm test` — but "locally" is the trap. Tests only protect you if they run automatically,
on a clean machine, before code is merged. A test suite nobody runs is documentation, not
a safety net.

So today we turn "please remember to run the tests" into "the tests ran, here's the green
check, and if they were red you couldn't have merged."

## What you'll build today

A CI job that, on every push touching `day2-node-ci/`:

1. checks out the code,
2. sets up Node **and caches npm downloads**,
3. installs dependencies reproducibly with `npm ci`,
4. runs the linter,
5. runs the tests with coverage,
6. uploads the coverage report as a downloadable **artifact**.

The reference is in `.github/workflows/day2-ci.yml`. Read it end to end.

## New tools

**`actions/setup-node`** — installs a specific Node version on the runner and, crucially,
caches your dependencies between runs:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '22'
    cache: 'npm'
    cache-dependency-path: day2-node-ci/package-lock.json
```

Without the cache, every run re-downloads every package from the internet — slow and
flaky. With it, the second run onward restores them in seconds. The cache key is derived
from your `package-lock.json`; change a dependency and the cache correctly refreshes. In a
monorepo you must tell it where the lockfile lives, hence `cache-dependency-path`.

**`npm ci` vs `npm install`.** `npm ci` installs *exactly* what the lockfile says and fails
loudly if `package.json` and the lockfile disagree. That strictness is precisely what you
want on a build server: reproducible, or it stops. `npm install` is for your laptop, where
you're changing dependencies on purpose.

**`defaults.run.working-directory`.** Because the project lives in a subfolder, we set this
once so every `run:` step starts inside `day2-node-ci/` — no repeating `cd` everywhere.

**Artifacts** (`actions/upload-artifact`) — files a job produces that you want to keep and
download afterward: coverage reports, build output, logs. Note `if: always()` on that step
so you still get the report even when a test fails — that's often when you want it most.

## The payoff: a failing job that blocks a merge

A green check is nice; the real value is the red X *stopping* bad code. On GitHub, go to
**Settings → Branches → Add branch protection rule** for `main`, and require the Day 2
status check to pass before merging. Now a pull request with a broken test literally cannot
be merged. That is CI earning its keep. (You'll rely on this again in the capstone.)

## Exercises

1. **Break a test, watch it block.** Change an assertion in `slug.test.js` so it fails.
   Open a pull request. Confirm the check goes red and the merge button is disabled (once
   branch protection is on).

2. **Add a case, keep it green.** `slugify` currently strips emoji along with punctuation.
   Add a test proving `slugify("Deploy 🚀 now")` becomes `deploy-now`, confirm it passes.

3. **Read the artifact.** After a run, download the `day2-coverage` artifact and open
   `coverage/lcov-report/index.html`. Find the line-coverage percentage.

4. **Docker exercise — containerize the test run.** The project has a `Dockerfile` that runs
   the tests inside a container. First locally:

   ```bash
   cd day2-node-ci
   docker build -t day2-tests .
   docker run --rm day2-tests
   ```

   Then add a **second job** to the workflow named `docker-test` that does the same on the
   runner. Give it a `name:`, `runs-on: ubuntu-latest`, and steps to `checkout`, then
   `docker build` and `docker run`. Push and confirm you now see **two** jobs in the run.
   Discuss: what does running tests in a container buy you that `setup-node` doesn't?
   (Answer that leads into tomorrow: the container *is* the artifact you ship.)

5. **Cache proof.** Look at the "Set up Node.js" step logs on your first run vs your second.
   Find the line that says the cache was restored. Roughly how much time did it save?

## Common pitfalls

- `npm ci` fails with "lockfile not found" → you didn't commit `package-lock.json`, or
  `cache-dependency-path` points to the wrong place. Both must match the project folder.
- Lint passes locally but fails in CI → you have an editor plugin auto-fixing on save.
  CI runs the raw command; run `npm run lint` yourself before pushing.
- Artifact is empty → the path is wrong, or coverage didn't generate. In a monorepo the
  artifact `path:` is relative to the repo root: `day2-node-ci/coverage/`.

## Recap

A CI pipeline is ordered stages — install, lint, test — on a clean machine, with caching to
stay fast and artifacts to keep evidence. Wired to branch protection, it stops broken code
from merging. Tomorrow we make CI build the thing we actually ship: a Docker image.
