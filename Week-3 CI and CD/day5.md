# Day 5 — The ecosystem & wiring jobs together

**Mini-project:** `day5-ecosystem/` · **Reference:** all workflows are complete and runnable

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | Marketplace literacy + the tj-actions story (why SHA pinning) | 25 min |
| 2 | Live: compose three actions into a PR-hygiene workflow | 25 min |
| 3 | Wiring — `needs`, job `outputs`, dynamic matrix, secret masking | 45 min |
| 4 | Reusable workflows (`workflow_call`) + the push-vs-pull deploy framing | 25 min |

Objectives: students can (1) evaluate and safely adopt a marketplace action,
(2) pass data between jobs with `needs`/`outputs`, (3) factor a pipeline into a
reusable workflow, and (4) explain why a CI pipeline should end at a trustworthy
artifact rather than reaching into a server over SSH.

---

## The problem

For two days the pipeline fought back, and most of the pain was *deployment* —
SSH keys, host verification, a box that may or may not be up. None of that was
teaching CI/CD; it was teaching yak-shaving. Today we stay entirely inside
GitHub. Every workflow here is green-able on a laptop with no server in the loop,
which frees us to actually learn how the pieces compose.

## Block 1 — Marketplace literacy

Open the [Actions Marketplace](https://github.com/marketplace?type=actions) and
"go shopping" together, but frame it as *evaluation*, not *installation*. Walk
the checklist in `SHA-PINNING.md`: who publishes it, how many repos use it, what
permissions it demands, and — the load-bearing habit — **pin to a commit SHA**.

Tell the tj-actions story (March 2025): one action used by 23,000+ repos was
compromised by **rewriting its version tags** to point at code that leaked
secrets into the logs. Pinning to `@v44` didn't save anyone; pinning to a SHA
did. This is the single most important 10 minutes of the day.

## Block 2 — Compose actions (`day5-pr-hygiene.yml`)

Build it live. Three actions, one useful outcome, zero infra:
`actions/labeler` (area labels) → `codelytv/pr-size-labeler` (size labels) →
`actions/github-script` (a sticky summary comment). Point out that the two
first-party actions and the one third-party action are all SHA-pinned, and that
`permissions:` is scoped to exactly `contents: read` + `pull-requests: write`.

Have a student open a PR touching `day5-ecosystem/**` and watch the labels and
comment appear. `day5-release.yml` is the same idea on a tag trigger — demo it if
time allows (`git tag day5-v1.0.0 && git push origin day5-v1.0.0`).

## Block 3 — Wiring jobs (`day5-wiring.yml`)

This is the meat and it cannot fail live. Trace the data flow on the board:

- `plan` computes a **version** and a **matrix** and writes them to
  `$GITHUB_OUTPUT`.
- `test` reads `needs.plan.outputs.matrix` through `fromJSON()` and fans out over
  Node 20 and 22.
- `package` reads `needs.plan.outputs.version` to name its artifact.
- `promote` runs inside the `staging` **environment**, prints a secret to prove
  it comes out as `***`, and writes a step summary.

Key beats: a job output is a string; `needs` is both an ordering edge *and* the
channel for `outputs`; secrets are masked automatically but are **not** encryption
— don't paste them into artifacts.

## Block 4 — Reusable workflows + deploy framing

Show `reusable-quality.yml` (`on: workflow_call`, typed `inputs`, a declared
`output`, named `secrets`) and its caller `day5-uses-reusable.yml`. The mental
model: a composite action packages *steps*; a reusable workflow packages *jobs*.

Close on the framing that sets up the capstone: a pipeline's job ends at a
tagged, trustworthy artifact. Getting it onto a server is a separate concern with
two shapes — **push** (CI reaches into prod: SSH, fragile) and **pull** (the
server converges toward the registry: robust, GitOps-shaped). Optional 5-minute
demo: a `systemd` timer or cron running `docker compose pull && docker compose up -d`
*is* a pull-based deploy in five lines.

> Off-the-shelf pull tools exist but check their pulse first: the classic
> `containrrr/watchtower` was archived in December 2025; the maintained fork is
> `nickfedor/watchtower`.

## Recap

Marketplace actions are powerful and dangerous; pin them to SHAs and scope their
permissions. `needs` + `outputs` let jobs hand work down a chain, including a
matrix computed at runtime. Reusable workflows package a whole pipeline behind a
typed interface. And deployment is not the pipeline's job — the pipeline's job is
to produce something worth deploying. Tomorrow: take that artifact to real AWS.
