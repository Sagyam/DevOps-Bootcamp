# Day 1 — Why CI/CD, and the anatomy of a workflow

**Mini-project:** `day1-hello/` · **Starter:** `day1-starter.zip`

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | The problem CI/CD solves — a story, not a definition | 20 min |
| 2 | Set up the shared repo, push, watch the first run | 30 min |
| 3 | Anatomy: event → job → runner → step → action | 40 min |
| 4 | Reading logs and contexts | 20 min |
| 5 | Exercises (incl. Docker) | 40 min |

Learning objectives: students can explain what CI/CD is and why it exists, can read a
workflow file line by line, and can trigger and inspect a run on GitHub.

---

## The problem

Picture the bootcamp's shared Ubuntu VM. Someone pushes code on Friday evening. It works
on their laptop. On Monday, three other students pull it and nothing runs — a missing
dependency, a test that was never run, a typo that only shows up on a clean machine. The
afternoon is gone to "but it worked for me."

Every team hits this. The fix is not "be more careful." Humans forget; that is what humans
do. The fix is a machine that, on **every single push**, checks out the code on a clean
computer and runs the same checks the same way, every time, without being asked.

That machine is **Continuous Integration (CI)**. When you extend it to also *ship* the
result — build the image, put it on a server — that is **Continuous Deployment (CD)**.

GitHub Actions is CI/CD built into the place your code already lives. No separate server to
run, no account to create. You describe the checks in a YAML file, commit it, and GitHub
runs them for you on machines it provides for free.

## What you'll build today

The smallest workflow that is still real: on every push that touches `day1-hello/`, GitHub
spins up a fresh Ubuntu machine, checks out your code, prints some context about the push,
and runs a tiny Node script. You will watch it happen live in the **Actions** tab.

## Set up the one repo you'll use all week

1. On GitHub, create an **empty** repository named `github-actions-bootcamp`
   (no README, no `.gitignore` — we bring our own).
2. Unzip `day1-starter.zip` into a new empty folder on the VM.
3. Push it:

   ```bash
   cd github-actions-bootcamp
   git init
   git add .
   git commit -m "Day 1: hello actions"
   git branch -M main
   git remote add origin git@github.com:<you>/github-actions-bootcamp.git
   git push -u origin main
   ```

4. Open the repo on GitHub → **Actions** tab. You should see "Day 1 - Hello Actions"
   running or done. Click it, click the `greet` job, and expand each step.

**This is the only repository you create this week.** Every following day drops new files
into this same folder. That is deliberate — real teams keep many projects and pipelines in
one place, and today you learn the trick that makes that painless.

## Anatomy of the workflow

Open `.github/workflows/day1-hello.yml` and read it against this vocabulary:

- **Workflow** — the whole YAML file. Lives in `.github/workflows/`. A repo can have many.
- **Event / trigger** — the `on:` block. *When* should this run? Here: a push or PR that
  touches Day 1's files, or a manual click (`workflow_dispatch`).
- **Job** — a named unit of work (`greet`). Jobs get a fresh machine each.
- **Runner** — the machine, chosen with `runs-on: ubuntu-latest`. GitHub hosts it.
- **Step** — one thing in a job, run top to bottom. A step either runs a shell command
  (`run:`) or uses a prebuilt **action** (`uses:`).
- **Action** — a reusable step someone published, like `actions/checkout@v4`, which pulls
  your code onto the runner.
- **Context** — data GitHub injects, read with `${{ ... }}` — who pushed, which commit,
  which branch.

The single most important line for the whole week is the path filter:

```yaml
on:
  push:
    paths:
      - 'day1-hello/**'
      - '.github/workflows/day1-hello.yml'
```

It says *only run me when Day 1's files change.* Tomorrow's workflow will say the same
about Day 2. That is how six pipelines share one repo without tripping over each other.

## Read the run

In the Actions tab, open your run and notice:

- The **event** that triggered it (push).
- The **"Show me the context"** step printing the branch, SHA, and your username.
- The **"Run the greeting"** step printing `Hello, bootcamp!` — proof that a value set in
  the workflow reached the program.

Then make it fail on purpose: edit `greet.js` to `throw new Error("boom")`, push, and watch
the red X. Read the log. Fix it. This loop — push, watch, read, fix — is the entire job.

## Exercises

1. **Trigger by hand.** Add nothing; just go to the Actions tab, pick the Day 1 workflow,
   and use "Run workflow" (that button exists because of `workflow_dispatch`). Confirm it
   runs with no code change.

2. **Change the greeting.** Make the workflow greet with your own name via the `GREET_NAME`
   env value. Push and confirm the log changes.

3. **Prove the path filter works.** Create a file `notes.txt` at the repo *root* and push.
   The Day 1 workflow should **not** run (nothing under `day1-hello/` changed). Explain to
   your neighbour why.

4. **Docker exercise — same code, in a container.** You already know Docker. Build and run
   the Day 1 image on the VM:

   ```bash
   cd day1-hello
   docker build -t day1-hello .
   docker run --rm -e GREET_NAME=Docker day1-hello
   ```

   Then add a step to the workflow that does the same thing on the runner:

   ```yaml
   - name: Run it inside Docker
     working-directory: day1-hello
     run: |
       docker build -t day1-hello .
       docker run --rm -e GREET_NAME=CI day1-hello
   ```

   Push and confirm the container ran on GitHub's machine. Note that `docker` is already
   installed on `ubuntu-latest` — no setup needed. Tomorrow we stop shelling out to Docker
   by hand and start doing it the pipeline way.

## Common pitfalls

- Workflow file not under `.github/workflows/` → GitHub never sees it. The path is exact.
- YAML is whitespace-sensitive. Two spaces, never tabs. A misaligned key silently breaks it.
- Nothing runs after your first push? Check you didn't only change files outside
  `day1-hello/` — the path filter is doing its job.

## Recap

CI/CD is a machine that runs your checks on every push so humans don't have to remember to.
A workflow is events → jobs → runners → steps → actions. Path filters keep many pipelines
politely out of each other's way. Tomorrow: a real pipeline with linting, tests, caching,
and an artifact.
