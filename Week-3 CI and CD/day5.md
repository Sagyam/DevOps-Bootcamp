# Day 5 — Secrets, environments, and deployment (the CD in CI/CD)

**Mini-project:** `day5-deploy/` · **Starter:** `day5-starter.zip`

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | The problem: building isn't shipping | 10 min |
| 2 | Secrets: what they are, how to store and read them | 30 min |
| 3 | Environments, approval gates, `needs` between jobs | 30 min |
| 4 | Deploy over SSH to a real VM | 35 min |
| 5 | Security: pin actions, least privilege, `concurrency` | 20 min |
| 6 | Exercises (incl. Docker) | 35 min |

Objectives: students store secrets safely, deploy a built image to an Ubuntu server over
SSH, gate that deploy behind an environment, and apply basic supply-chain hygiene.

---

## The problem

You can build and push an image (Day 3). But a registry isn't a running service — nobody's
using an image sitting in GHCR. Deployment is the step where the new image replaces the old
one on a server and starts serving traffic. That step needs credentials (an SSH key, maybe
a database URL) that must **never** appear in your code or logs, and it needs guardrails so
a bad push doesn't instantly take production down.

Today CI finishes the job: build → push → **deploy** to a real Ubuntu VM over SSH — the same
kind of machine your bootcamp already runs on.

## Secrets: the one rule

Credentials go in **repository secrets**, never in files. On GitHub:
**Settings → Secrets and variables → Actions → New repository secret**. Create:

| Secret     | Value                                            |
|------------|--------------------------------------------------|
| `SSH_HOST` | your server IP/hostname                          |
| `SSH_USER` | login user, e.g. `ubuntu`                        |
| `SSH_KEY`  | a **private** key whose public half is on the server |

Read them in the workflow as `${{ secrets.SSH_HOST }}`. GitHub masks their values in logs —
if a secret would be printed, it shows as `***`. This is why you never `echo` a secret to
debug; you'd just see stars, and you risk leaking it through a transform. Secrets are
write-only from the UI: you can update but never read them back.

## New tools

**Jobs that depend on jobs — `needs`.** The workflow has two jobs: `build` produces the
image and outputs a version; `deploy` waits for it:

```yaml
deploy:
  needs: build
```

`deploy` won't start until `build` succeeds, and it reads
`${{ needs.build.outputs.version }}` to know which image to pull. Passing data between jobs
via `outputs` is a core pattern.

**Environments and approval gates.** Binding a job to a named environment unlocks
protection rules and environment-scoped secrets:

```yaml
environment:
  name: production
  url: http://${{ secrets.SSH_HOST }}:3000/health
```

Under **Settings → Environments → production**, add a **required reviewer**. Now the deploy
job *pauses* and waits for a human to click "Approve" before it runs. That's how you get
continuous *delivery* (ready to ship any time, a human presses go) versus fully automatic
continuous *deployment*. The `url:` gives you a clickable link to the deployed service right
from the run summary.

**Deploy over SSH.** `appleboy/ssh-action` opens an SSH session using your secrets and runs
a script on the server — pull the new image, remove the old container, run the new one:

```yaml
- uses: appleboy/ssh-action@v1
  with:
    host: ${{ secrets.SSH_HOST }}
    username: ${{ secrets.SSH_USER }}
    key: ${{ secrets.SSH_KEY }}
    script: |
      IMAGE=ghcr.io/${{ github.repository }}/day5-app:${{ needs.build.outputs.version }}
      docker pull "$IMAGE"
      docker rm -f day5-app 2>/dev/null || true
      docker run -d --name day5-app -p 3000:3000 --restart unless-stopped "$IMAGE"
```

Because the image is tagged with the commit SHA (baked in as `APP_VERSION`), you can hit
`/health` after deploy and confirm the exact commit that's live.

## Security hygiene (start these habits now)

- **Least privilege:** the build job declares `permissions: contents: read, packages:
  write` — nothing more.
- **`concurrency`:** `cancel-in-progress: true` on a `day5-deploy` group means a newer push
  cancels an in-flight deploy, so two deploys never race to touch the server at once.
- **Pin third-party actions.** `appleboy/ssh-action@v1` is convenient; for anything
  security-sensitive in a real repo, pin to a full commit SHA so a compromised tag can't
  silently change what runs. Discuss the trade-off with the class.
- **Never log secrets**, never pass them into untrusted build steps.

## Exercises

1. **First real deploy.** Point `SSH_*` at your bootcamp VM (or a throwaway cloud VM), push
   a change to `day5-deploy/`, approve the environment, then
   `curl http://<host>:3000/health` and confirm the `version` matches your commit.

2. **Add the human gate.** Turn on a required reviewer for `production`. Push again and
   watch the deploy job wait. Approve it and watch it proceed.

3. **Prove secret masking.** Add a temporary step `run: echo "host is ${{ secrets.SSH_HOST
   }}"`. Confirm the log prints `***`, not your host. Remove the step.

4. **Docker exercise — zero-ish-downtime restart.** The current script does `rm -f` then
   `run` — a brief gap. On the server, sketch a safer swap: start the new container on a
   temporary name/port, health-check it, then flip. Discuss what a real setup (a reverse
   proxy, or `docker compose up -d` with a healthcheck) buys you.

5. **Rollback.** Because every image is SHA-tagged, "rollback" is just deploying an older
   tag. Manually run the deploy against the previous SHA and confirm `/health` reports the
   old version. This is why immutable, SHA-tagged images matter.

## Common pitfalls

- `Permission denied (publickey)` → the **public** key isn't in the server's
  `~/.ssh/authorized_keys`, or you stored the wrong half in `SSH_KEY`. The secret holds the
  **private** key.
- Deploy runs but nothing changes → the server pulled a cached tag. SHA tags avoid this;
  never deploy by `:latest` alone.
- Private GHCR image won't pull on the server → the server needs its own
  `docker login ghcr.io`. A public package needs none.

## Recap

Deployment turns a built image into a running service. Secrets keep credentials out of code;
environments add human gates and scoped secrets; `needs` and `outputs` pass the baton
between jobs; SHA tags make deploys traceable and rollbacks trivial. Tomorrow you assemble
everything into one capstone pipeline.
