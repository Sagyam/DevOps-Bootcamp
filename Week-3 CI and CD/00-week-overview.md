# CI/CD with GitHub Actions — 6-Day Plan

A one-week module for students who already know **Linux** and **Docker**. Each day is one
lesson file and one mini-project. Everything lives in a **single repository**
(`github-actions-bootcamp`) — students clone it once on Day 1 and grow it. Docker exercises
are woven into every day.

## The arc

| Day | Theme | Mini-project | Docker angle | New Actions concepts |
|-----|-------|--------------|--------------|----------------------|
| 1 | Why CI/CD; workflow anatomy | `day1-hello` | Run the app in a container step | events, jobs, runners, steps, actions, contexts, **path filters** |
| 2 | A real CI pipeline | `day2-node-ci` | Containerize the test run as a 2nd job | `setup-node`, npm cache, `npm ci`, lint/test stages, artifacts, branch protection |
| 3 | Build & ship images | `day3-docker-app` | Multi-stage build, layer cache in CI | Buildx, GHCR, `GITHUB_TOKEN`, `permissions`, `metadata-action`, `build-push-action` |
| 4 | Real infra & reuse | `day4-integration` | Service containers vs compose; run image | **service containers** (Postgres+Redis), **matrix**, **composite action**, per-cell artifacts |
| 5 | Deploy (the CD) | `day5-deploy` | Pull & restart on the server; safe swap | **secrets**, **environments** + approval, `needs`/`outputs`, SSH deploy, `concurrency`, action pinning |
| 6 | Capstone | `day6-capstone` | Full local dry-run with compose | everything, assembled by the students against a spec + rubric |

## The one design decision: one repo, many pipelines

Six workflows share one repository. Each is **path-scoped** so it only runs when its own
folder changes:

```yaml
on:
  push:
    paths:
      - 'dayN-name/**'
      - '.github/workflows/dayN-name.yml'
```

This is taught explicitly on Day 1 and reinforced daily. It mirrors how real monorepos keep
independent services' pipelines from triggering each other — a genuinely useful skill, not
just a bootcamp convenience.

## How students use the starters

- **Day 1:** unzip `day1-starter.zip` into an empty folder (it brings the repo scaffold —
  README, `.gitignore`, first project, first workflow), then `git init` and push to a new
  empty GitHub repo.
- **Days 2–6:** unzip that day's starter **on top of the same folder**. Nothing is ever
  overwritten — each day only adds files under a new `dayN-*` folder (plus its own workflow,
  and on Day 4 the shared composite action). Commit and push.

Every mini-project's code is real and runs: the Node apps have working tests (verified),
the Dockerfiles are multi-stage and non-root, and every workflow is valid YAML.

## Teaching stance

- **Problem-first:** each lesson opens with a concrete pain (usually one your students have
  already felt on the shared VM), then introduces the feature that removes it.
- **Language is incidental:** Node is used because its tooling makes CI concepts visible
  fast. The Actions concepts are language-agnostic; say so.
- **Red is the point:** every day includes "break it on purpose" so students read failures,
  not just admire green checks.

## Prerequisites to check before Day 1

- Each student has a GitHub account and can push over SSH from the VM.
- Docker is available on the VM (it already is, from the Docker week).
- For Day 5, one reachable Ubuntu server per student (or a shared one, or a throwaway cloud
  VM) they can SSH into as a deploy target.
