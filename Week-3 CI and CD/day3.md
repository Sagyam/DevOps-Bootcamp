# Day 3 — Docker images, built and pushed by CI

**Mini-project:** `day3-docker-app/` · **Starter:** `day3-starter.zip`

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | Recap: the container is the deliverable | 10 min |
| 2 | Building images on a runner: Buildx | 25 min |
| 3 | Registries; logging in to GHCR with `GITHUB_TOKEN` | 25 min |
| 4 | Tagging with `metadata-action`; push | 30 min |
| 5 | Layer caching in CI | 25 min |
| 6 | Exercises (Docker-heavy) | 40 min |

Objectives: students make CI build a multi-stage image, push it to GHCR with sensible tags,
and use registry-level layer caching — no manual `docker push` ever again.

---

## The problem

You've spent a week on Docker. On your laptop the loop is: edit code, `docker build`,
`docker push`, then someone SSHes somewhere and pulls it. Every one of those manual steps
is a chance to push the wrong tag, forget to rebuild, or ship your uncommitted local edits.

The container image is the real deliverable — it's what runs in production. So the same
machine that runs your tests should build that image and push it to a registry, from the
exact committed code, tagged so you always know which commit an image came from.

## What you'll build today

On every push touching `day3-docker-app/`, CI will: run the tests, build the **multi-stage**
image (the exact idea from your Docker multi-stage lesson), log in to the **GitHub
Container Registry (GHCR)**, tag the image by branch and commit, and push it — with **layer
caching** so rebuilds are fast. Reference: `.github/workflows/day3-docker.yml`.

## The Dockerfile is already good — read why

Open `day3-docker-app/Dockerfile`. It's the multi-stage pattern you know:

- **build stage** installs dependencies with the full toolchain,
- **runtime stage** copies only what's needed to run, runs as a non-root `USER node`, and
  declares a `HEALTHCHECK`.

Multi-stage matters more in CI than on your laptop, because CI builds this image on every
push — a smaller, safer image compounds over hundreds of builds.

## New tools

**`docker/setup-buildx-action`** — enables Buildx, Docker's advanced builder. You need it
for the caching features below.

**Registries and GHCR.** An image has to live somewhere a server can pull it from — a
registry. GitHub gives every repo one at `ghcr.io`. The magic is auth: you don't create any
secret. GitHub hands every workflow a temporary `GITHUB_TOKEN`, and with
`permissions: packages: write`, that token can push to *this* repo's registry:

```yaml
permissions:
  contents: read
  packages: write
# ...
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

`permissions:` is least-privilege in action — the job can write packages and read code, and
nothing else. Get in the habit; the capstone will expect it.

**`docker/metadata-action`** — computes good tags automatically. We tag by branch name and
by short commit SHA, so every image is traceable to the exact commit that built it. Never
rely on `:latest` alone — you can't tell two `:latest` images apart.

**`docker/build-push-action`** with GitHub-cache layers:

```yaml
- uses: docker/build-push-action@v6
  with:
    context: day3-docker-app
    push: ${{ github.event_name != 'pull_request' }}
    tags: ${{ steps.meta.outputs.tags }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

`cache-from`/`cache-to: type=gha` store your image layers in GitHub's Actions cache. A
rebuild that only changed source code reuses the dependency layers — exactly the layer
caching you learned locally, now shared across CI runs. Note `push:` is false on pull
requests: PRs from forks can't (and shouldn't) push, so we build to verify but don't
publish.

## See the result

After the workflow runs on `main`, open your repo's main page → **Packages** (right
sidebar). Your image is there, tagged by SHA. Pull it from anywhere:

```bash
docker pull ghcr.io/<you>/github-actions-bootcamp/day3-app:main
docker run --rm -p 3000:3000 ghcr.io/<you>/github-actions-bootcamp/day3-app:main
curl "localhost:3000/slug?text=Hello%20from%20CI"
```

## Exercises

1. **Trace an image to a commit.** Push a small change, note the short SHA, and confirm a
   new image tag with that SHA appears under Packages.

2. **Docker exercise — shrink the image.** Run `docker images` after a build and note the
   size. The build stage installs with `npm install`; change the runtime stage to also drop
   any dev files it doesn't need, rebuild, and compare sizes. Report the before/after.

3. **Docker exercise — prove the cache.** Push a change to `README.md` inside
   `day3-docker-app/` only (not the source). Watch the build log: most layers should say
   **CACHED**. Then change `src/server.js` and push again — notice which layers rebuild and
   which stay cached, and connect it to the `COPY` order in the Dockerfile.

4. **Add a `latest` tag on main.** Extend the `metadata-action` tags so pushes to `main`
   also get a `latest` tag, while feature branches don't. (Hint: `type=raw,value=latest`
   with an `enable=` condition.)

5. **Break the build, read the failure.** Introduce a typo in the Dockerfile's `CMD`. Push,
   read exactly where `build-push-action` fails, fix it. Building in CI means build errors
   are caught centrally, not "on my machine only."

## Common pitfalls

- `denied: permission_denied` on push → you forgot `permissions: packages: write`, or
  you're on a pull request from a fork (expected — those can't push).
- Image built but not pushed → check your `push:` expression; on PRs it's intentionally
  false.
- Cache never hits → your `COPY` order copies source before installing deps, so every
  source change busts the dependency layer. Copy `package*.json` and install first.

## Recap

CI now produces the real artifact — a tagged, traceable Docker image in GHCR — with no
manual push and with layer caching for speed. Tomorrow: tests that need a real database and
cache, run across multiple Node versions, using service containers and matrices.
