# Day 5 — Secrets, environments, and deployment

Building an image is continuous *integration*. Putting it on a running server is
continuous *deployment*. Today CI builds, pushes, and then **deploys over SSH** to a real
Ubuntu server — the same kind of VM your bootcamp already runs on.

## Secrets you must create first

In your repo: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret name   | What it is                                             |
|---------------|--------------------------------------------------------|
| `SSH_HOST`    | Your server's IP or hostname                            |
| `SSH_USER`    | The login user (e.g. `ubuntu`)                          |
| `SSH_KEY`     | A **private** SSH key whose public half is on the server |

Never paste any of these into a workflow file. Workflows read them as
`${{ secrets.SSH_HOST }}`, and GitHub masks their values in the logs.

## What the deploy does

The workflow at `../.github/workflows/day5-deploy.yml`:

1. Builds the image, tagging it with the commit SHA as the version.
2. Pushes it to GHCR.
3. Waits for approval (the `production` **environment** can require a manual click).
4. SSHes to your server, pulls the new image, and restarts the container.

Verify a deploy landed:

```bash
curl http://<SSH_HOST>:3000/health   # version should match the commit you pushed
```
