# GitHub Actions Bootcamp

One repository. Six days. Every mini-project lives here as its own folder, and every
workflow is scoped so it **only runs when its own folder changes**. You will never create
a second repository during this week — you clone this once and grow it.

## How this repo is organised

```
github-actions-bootcamp/
├── .github/
│   └── workflows/          # one workflow file per day, path-scoped
│       ├── day1-hello.yml
│       ├── day2-ci.yml
│       ├── day3-docker.yml
│       ├── day4-integration.yml
│       ├── day5-deploy.yml
│       └── day6-capstone.yml
├── day1-hello/             # each day's mini-project
├── day2-node-ci/
├── day3-docker-app/
├── day4-integration/
├── day5-deploy/
└── day6-capstone/
```

## The one rule that makes this work: path filters

If six workflows all ran on every push, a one-line fix in `day2` would trigger the Docker
build in `day3`, the integration tests in `day4`, and so on. That is noise, wasted runner
minutes, and confusing red X's on unrelated work.

Every workflow in this repo starts like this:

```yaml
on:
  push:
    paths:
      - 'dayN-name/**'
      - '.github/workflows/dayN-name.yml'
  pull_request:
    paths:
      - 'dayN-name/**'
  workflow_dispatch:
```

`paths:` tells GitHub: *only run me when a file inside this folder (or my own definition)
changed.* That is how a monorepo keeps six independent pipelines from stepping on each
other. You will see and use this pattern every single day.

## Getting started (Day 1)

1. Create an **empty** repository on GitHub named `github-actions-bootcamp`.
2. Unzip `day1-starter.zip` into an empty folder — it contains this README, `.gitignore`,
   `day1-hello/`, and `.github/workflows/day1-hello.yml`.
3. `git init`, commit, and push to the repo you just created.
4. Open the **Actions** tab on GitHub and watch your first workflow run.

Each following day you unzip that day's starter **on top of the same folder**, commit, and
push. Nothing is ever overwritten because every day adds new files under a new folder.

## Conventions used all week

- Node.js is the application language, because its tooling (`npm`, ESLint, Jest) makes CI
  concepts visible quickly. The GitHub Actions concepts are language-agnostic.
- Every app has a `Dockerfile`. You already know Docker — here you learn to make CI build,
  test, push, and deploy those images for you.
- Secrets are never committed. Where a workflow needs one, the lesson tells you exactly
  which repository secret to create.
