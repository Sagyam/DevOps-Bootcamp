# Docker: A 7-Day Hands-On Guide

A practical, step-by-step companion to the Docker & Containers slides. Each day pairs a few
core ideas with commands you run yourself. The goal is simple: by the end you can package an
app, ship it to a registry, and run it anywhere — reliably.

Read the idea, run the command, watch what happens. Don't just copy-paste; predict the result
first, then check whether you were right.

---

## Before you start

Docker is installed on your own machine, so the whole daemon is yours — nothing you name or
publish collides with anyone else. First, confirm it's working:

```bash
docker version                # client and server (daemon) should both report a version
docker run --rm hello-world   # pulls a tiny image and runs it once
```

A few conventions this guide follows, so the commands line up as you read:

1. **Plain names.** Containers are named `web`, `db`, and so on; images `myapp:1`; networks
   `appnet`; volumes `appdata`. Rename them however you like — just stay consistent.
2. **Fixed ports.** Apps are published on `8080` (and `8081`–`8083` when we run several at once).
   If something on your machine already uses one of these, pick another free port and adjust the
   command.
3. **Clean up when you're done.** Remove the containers you made by name, e.g.
   `docker rm -f web`, and drop any network or volume with `docker network rm appnet` /
   `docker volume rm appdata`. Because it's your own machine, `docker system prune` is now a safe
   way to reclaim space — it removes stopped containers, unused networks, and dangling images.

---

# Day 1 — Foundations

**Slides:** Why containers · What a container is · Containers vs VMs · The ecosystem · Architecture

Today you don't build anything. You prove to yourself what a container actually is.

### Key ideas

- A **container** is like a shipping container: your app plus everything it needs, sealed into
  a standard box that runs the same on any machine with a runtime.
- A container **shares the host's kernel**. A virtual machine brings its own entire operating
  system instead — that's why a VM is measured in gigabytes and starts in seconds, while a
  container is megabytes and starts in milliseconds.
- **Namespaces** are the walls that give a container its own isolated view. **cgroups** are the
  limits on how much CPU and memory it's allowed to use.

### Commands you'll use

`docker run`, `docker version`, `docker info`, `uname -r`, `ps`, and the flags `--rm`,
`--memory`, `--cpus`.

### Steps

**1.1 — Run your first container**

```bash
docker run --rm hello-world
```

Read every line it prints. In your own words, trace what happened: the client sent a command,
the daemon didn't have the image, it pulled it, created a container, ran it, and it exited.
That sentence is the whole architecture diagram.

**1.2 — Prove the kernel is shared**

```bash
uname -r                              # the host's kernel
docker run --rm alpine uname -r       # the container's kernel
```

They are identical. There is no separate operating system inside the container.

**1.3 — See the isolation**

```bash
docker run --rm alpine ps aux         # the container sees only its own processes
ps aux | head                         # the host sees hundreds
```

Same kernel, completely different view. That different view is a namespace.

**1.4 — See the limits**

```bash
docker run --rm --memory=64m alpine sh -c 'echo "capped at 64MB RAM"'
docker run --rm --cpus=0.5 alpine sh -c 'echo "capped at half a CPU"'
```

Namespaces decide what a container can *see*; cgroups decide how much it can *take*.

**1.5 — Look at the runtime stack**

```bash
docker info | grep -i runtime
```

You'll see `runc`. The chain is: your `docker` command → the `dockerd` daemon → `containerd`
→ `runc` → the kernel.

### If you finish early

Run `docker run --rm -it alpine sh`, then inside type `cat /etc/os-release`. You appear to be
"inside Alpine" even though your host is a different Linux. Work out how that's possible with only
one shared kernel. (Hint: it's a different set of files, not a different engine.)

### Check yourself

1. Why does a container start in milliseconds but a VM in seconds?
2. What does a VM include that a container deliberately leaves out?
3. Which kernel feature provides isolation, and which one limits resources?

### Common mistake

"A container is just a lightweight VM." It isn't. A VM virtualises hardware and runs its own OS;
a container isolates a process and shares the host kernel. If there's no shared kernel, it isn't
a container.

---

# Day 2 — Running Containers

**Slides:** Installing Docker · Image to container · The lifecycle · `docker run` · Publishing ports · Inspect and clean up

Now you operate containers by hand: pull an image, run it, expose it, look inside, remove it.

### Key ideas

- An **image** is a read-only template; a **container** is a running instance of that image.
  Think of the image as a recipe and the container as the dish, or the image as a class and the
  container as an object. One image can produce many containers.
- A running container has a thin **writable layer** on top. Anything written there is lost when
  the container is removed.
- **Publishing a port** with `-p` is what connects the outside world to a port inside the
  container. Without it, nothing can reach the app.

### Commands you'll use

`docker pull`, `docker images`, `docker run` (`-d --name -p -e -v -it --rm`), `docker ps -a`,
`docker logs -f`, `docker exec -it`, `docker stop/start/pause/unpause`, `docker rm/rmi`.

### Steps

**2.1 — Pull a specific image**

```bash
docker pull nginx:1.27
docker images | grep nginx
```

**2.2 — Run it in the background and reach it**

```bash
docker run -d --name web -p 8080:80 nginx:1.27
curl -s localhost:8080 | head -n 4
```

You published your own port `8080` to port `80` inside the container.

**2.3 — Walk the lifecycle**

```bash
docker pause   web && docker ps      # look for the Paused state
docker unpause web
docker stop    web && docker ps -a   # gone from `ps`, still listed in `ps -a`
docker start   web
```

Match each command to the lifecycle diagram: Created, Running, Paused, Stopped, Removed.

**2.4 — Look inside a running container**

```bash
docker exec -it web bash
# inside: ls /usr/share/nginx/html ; exit
docker logs --tail 5 web
```

`exec` opens a shell inside a container that's already running. `logs` shows what it has printed.

**2.5 — One image, many containers**

```bash
for n in 1 2 3; do
  docker run -d --name web-$n -p $((8080+n)):80 nginx:1.27
done
docker ps
```

Three identical containers from one image, on ports `8081`, `8082`, and `8083`. This is scaling,
done by hand for now.

**2.6 — Clean up your containers**

```bash
docker rm -f web web-1 web-2 web-3
docker ps -a                          # your exercise containers should be gone
```

### If you finish early

Run a throwaway container: `docker run -it --rm ubuntu bash`. Make a mess inside, then `exit`.
Confirm with `docker ps -a` that `--rm` left nothing behind. When would you want that instead
of `-d`?

### Check yourself

1. What three things does `docker run` do in order?
2. A stopped container still uses something — what, and how do you reclaim it?
3. In `-p 8080:80`, which number is the host port and which is the container port?

### Common mistake

`EXPOSE` in a Dockerfile does not publish a port — only `-p` does. Also remember `docker rm`
removes a *container* but leaves the *image* on disk; `docker rmi` removes the image.

---

# Day 3 — Building Images with a Dockerfile

**Slides:** Hand-built containers don't scale · Anatomy of a Dockerfile · Instruction reference · CMD vs ENTRYPOINT

So far you've run images other people built. Now you write the instructions to build your own,
so that anyone can rebuild exactly the same image.

### Key ideas

- A **Dockerfile** is a plain-text recipe for an image. It lives in git, so it's reviewable and
  repeatable. The rule to remember: *if it isn't in the Dockerfile, it doesn't exist.*
- **CMD** sets the default command, and it's easy to override at run time. **ENTRYPOINT** sets
  the program that always runs; anything you pass on the command line becomes arguments to it.

### Commands you'll use

`docker build -t`, and the instructions `FROM WORKDIR COPY RUN ENV EXPOSE USER CMD ENTRYPOINT`,
plus a `.dockerignore` file.

### The app you'll build

Make a folder `~/myapp` and put this file in it. It uses only Python's standard library, so
there's nothing to install:

```python
# server.py
import http.server, os
port = int(os.environ.get("PORT", "8000"))
msg  = os.environ.get("GREETING", "Hello from my container")
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(f"{msg} (port {port})\n".encode())
print(f"serving on {port}")
http.server.HTTPServer(("", port), H).serve_forever()
```

### Steps

**3.1 — Write and build your first image**

```dockerfile
# Dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY server.py .
ENV PORT=8000
EXPOSE 8000
CMD ["python", "server.py"]
```

```bash
cd ~/myapp
docker build -t myapp:1 .
docker run -d --name app -p 8080:8000 myapp:1
curl -s localhost:8080
```

**3.2 — Add a `.dockerignore`**

```bash
printf '.git\n__pycache__\n*.log\nREADME.md\n' > .dockerignore
```

Everything in the folder is sent to the daemon as the "build context." Keep junk and secrets
out of it.

**3.3 — Override CMD**

```bash
docker run --rm -e GREETING="custom message" myapp:1
docker run --rm myapp:1 python -c "print('I replaced the CMD')"
```

The second command replaced CMD entirely. That's how easily CMD is overridden.

**3.4 — Compare with ENTRYPOINT**
Build a second version that pins the program:

```dockerfile
# Dockerfile.entry
FROM python:3.12-slim
WORKDIR /app
COPY server.py .
ENTRYPOINT ["python", "server.py"]
```

```bash
docker build -f Dockerfile.entry -t myapp:entry .
docker run --rm myapp:entry --help     # the arguments go TO python, they don't replace it
```

With ENTRYPOINT, command-line arguments are appended to the program instead of replacing it.

**3.5 — Stop running as root**
Add these two lines before `CMD` in your first Dockerfile, then rebuild:

```dockerfile
RUN useradd -m appuser
USER appuser
```

```bash
docker build -t myapp:1 .
docker run --rm myapp:1 whoami     # should print appuser, not root
```

### If you finish early

Break the build on purpose: point a `COPY` at a file that doesn't exist. Read the error message
carefully, then fix it. Reading a failed build is half the skill.

### Check yourself

1. Why is a Dockerfile better than configuring a container by hand and saving it?
2. You want users to be able to swap the command easily — CMD or ENTRYPOINT?
3. What is the "build context," and why does `.dockerignore` matter?

### Common mistake

Use the bracket form: `CMD ["python", "server.py"]`, not `CMD python server.py`. The bracket
("exec") form runs your program directly; the plain form wraps it in a shell and can break how
the container handles stop signals.

---


# Day 4 — Smaller, Faster, Safer Images

> **DevOps Bootcamp · Docker Module**

---

## Learning objectives

By the end of today, a student can:

1. Explain **why** image size and layer count matter (build time, push/pull, attack surface, cost).
2. Convert a naive single-stage Dockerfile into a **multi-stage build**.
3. **Measure and compare** image sizes with `docker images`, `docker history`, and `dive`.
4. Diagnose the classic **"it builds but won't run"** failure — and know *why* the error message lies to you.
5. Identify and fix the **common mistakes that silently break layer caching**.
6. **Scan** an image for vulnerabilities with `docker scout` (and Trivy) and act on the results.


---

A big image is not just "storage." It costs you on every axis:

- **Build time** — more layers, more to rebuild when cache misses.
- **Push/pull time** — CI pushes it, every node pulls it, every deploy waits on it. A 1 GB image vs a 15 MB image is the difference between a 3-minute rollout and a 5-second one.
- **Attack surface** — every package in the image is something that can have a CVE. A full `node:22` image has *hundreds* of OS packages you never use. `scratch` has zero.
- **Cost** — registry storage, egress, and slower autoscaling all show up on a bill.

The whole lesson is one idea: **ship only what runs, nothing that builds.**

---

## 1 · Baseline — the naive image

We'll use a tiny Go HTTP server as our running example, because it makes the size story dramatic *and* it's the perfect vehicle for today's "won't run" bug. (A Node version appears in §4 for the interpreted-language case.)

**Project layout**

```
shortlink/
├── go.mod
├── go.sum
└── cmd/server/main.go
```

**`cmd/server/main.go`** (minimal, no external deps):

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "hello from shortlink")
	})
	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

**The naive Dockerfile** — `Dockerfile.naive`:

```dockerfile
FROM golang:1.23
WORKDIR /src
COPY . .
RUN go build -o /app/server ./cmd/server
EXPOSE 8080
CMD ["/app/server"]
```

Build it and look at the damage:

```bash
docker build -f Dockerfile.naive -t shortlink:naive .
docker images shortlink:naive
```

You'll see something around **800 MB – 1 GB**. The *entire Go toolchain* — compiler, stdlib source, git, build caches — is riding along in production, even though production only needs one ~10 MB binary.

> **Teaching beat:** ask the room *"what in this image does the running program actually use?"* Answer: the binary. Everything else is build-time baggage. That's the problem multi-stage solves.

---

## 2 · Multi-stage builds

A multi-stage Dockerfile has **more than one `FROM`**. Each `FROM` starts a fresh stage. You do the heavy building in an early stage, then **copy just the finished artifact** into a clean, tiny final stage. The build stage is discarded — it never ships.

`Dockerfile`:

```dockerfile
# ---- Stage 1: build ----
FROM golang:1.23 AS builder
WORKDIR /src

# copy dependency manifests first (see §6 — caching)
COPY go.mod go.sum ./
RUN go mod download

# now the source
COPY . .

# static binary — remember CGO_ENABLED=0, this matters in §3
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

# ---- Stage 2: runtime ----
FROM scratch
COPY --from=builder /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

Key syntax:

- `FROM golang:1.23 AS builder` — names the stage so we can reference it.
- `COPY --from=builder /server /server` — pulls one file out of the build stage into the final image.
- `FROM scratch` — the empty base. Literally nothing: no shell, no libc, no package manager.

Build and compare:

```bash
docker build -t shortlink:multi .
docker images | grep shortlink
```

```
shortlink   naive   ...   ~850MB
shortlink   multi   ...   ~11MB
```

Roughly **a 75× reduction**, and the runtime image contains exactly one thing an attacker could target: your binary.

> The build stage still exists on your machine as cache — that's a feature. Rebuilds reuse it. It just never becomes part of the shipped image.

---

## 3 · "It builds but won't run" — the bug from last time

This is the section that matters most, because it's the exact failure that can derail a live session. We're going to **cause it on purpose**, read the error carefully, and fix it — so students internalize the *why*.

### Reproduce the failure

Take the multi-stage Dockerfile above and **remove `CGO_ENABLED=0`**:

```dockerfile
RUN GOOS=linux go build -o /server ./cmd/server   # no CGO_ENABLED=0
```

For a program that pulls in anything using cgo (a SQLite driver, certain `net` configurations, etc.), Go produces a **dynamically linked** binary. Build succeeds. Then:

```bash
docker build -t shortlink:broken .
docker run --rm shortlink:broken
```

```
exec /server: no such file or directory
```

### Why the error is lying to you

The file is *right there.* You can prove it. So what "does not exist"?

A dynamically linked ELF binary doesn't start on its own — the kernel hands it to a **dynamic loader** (`/lib64/ld-linux-x86-64.so.2`) which then pulls in `libc`. In a `scratch` image, **none of those files exist.** The kernel tries to `exec` the loader named inside your binary, can't find it, and returns `ENOENT` — which the shell surfaces as *"no such file or directory."* The message is about the **missing interpreter**, not your binary.

You get the **same error with `FROM alpine`** for a different reason: Alpine uses **musl** libc, not **glibc**. A glibc-linked binary asks for a glibc loader that Alpine doesn't have. Same `no such file or directory`, same root cause: **the runtime stage doesn't have the libc your binary was linked against.**

### The whole family of "builds but won't run" errors

Give students this table — it's the debugging cheat sheet:

| Error at `docker run` | What it really means | Fix |
|---|---|---|
| `exec /app: no such file or directory` (file *is* present) | Dynamic loader / libc missing in final stage (glibc binary → scratch or alpine/musl) | `CGO_ENABLED=0` for a static binary, **or** use a matching-libc base (`debian:bookworm-slim`, `distroless`) |
| `exec /app: exec format error` | Architecture mismatch (arm64 binary on amd64 host, or vice-versa — common on Apple Silicon) | Build for the target: `docker build --platform linux/amd64 …` / use `buildx` |
| `no such file or directory` (file genuinely absent) | Wrong `COPY --from` source/dest path; binary landed elsewhere than `CMD` expects | Verify paths; use absolute paths; `docker run --rm -it img ls -l /` |
| `permission denied` | Copied file isn't executable | `COPY --chmod=0755 …` or `RUN chmod +x /server` |
| `exec: "sh": ... not found` | Shell-form `CMD` in an image with no shell (scratch/distroless) | Use **exec form** with the binary directly: `ENTRYPOINT ["/server"]` |
| App starts, then `x509: certificate signed by unknown authority` | No CA certificates in a minimal base | Copy certs from builder, or use a base that includes them (distroless does) |

### The debugging *method* (teach the process, not just the fix)

1. **Read the exact error. Don't guess.** The message *is* the diagnosis once you know the table above.
2. **Isolate: is it the binary or the runtime stage?** Run the *builder* stage directly:
   ```bash
   docker build --target builder -t shortlink:builder .
   docker run --rm shortlink:builder /server
   ```
   If it runs here but not in the final image → the problem is in your runtime stage (missing loader/libc/certs), not your code.
3. **Check whether the binary is static:**
   ```bash
   docker run --rm shortlink:builder ldd /server
   ```
   `not a dynamic executable` → static, safe for `scratch`. A list of `.so` files → dynamic, needs a matching libc.
4. **If the final image has a shell** (alpine/slim), poke around inside:
   ```bash
   docker run --rm -it shortlink:multi sh
   ```
   If it's `scratch`/distroless (no shell), temporarily swap the final `FROM` to `busybox` or `alpine` just to inspect, then switch back.
5. **Confirm what Docker actually runs:**
   ```bash
   docker inspect --format '{{.Config.Entrypoint}} {{.Config.Cmd}} {{.Config.WorkingDir}}' shortlink:multi
   ```

### The fix

Put `CGO_ENABLED=0` back. Now `ldd` reports a static binary and it runs in `scratch`. If you genuinely need cgo (native SQLite, etc.), **don't** use `scratch` — use a base with the matching libc:

```dockerfile
# needs cgo/glibc → don't ship to scratch
FROM gcr.io/distroless/base-debian12
COPY --from=builder /server /server
ENTRYPOINT ["/server"]
```

> **Instructor note:** demo the broken build *live and on purpose*. Watching the `no such file or directory` error appear and then explaining that the file exists is one of those moments that sticks for years. It reframes a scary error as a known, named thing.

---

## 4 · Choosing a base image

The final-stage base is the single biggest lever on size *and* CVE count. From heaviest to lightest:

| Base | Size (approx) | Has shell? | libc | Use when |
|---|---|---|---|---|
| `golang:1.23` / `node:22` | 800 MB–1 GB | yes | glibc | build stage only |
| `debian:bookworm-slim` | ~75 MB | yes | glibc | need glibc + a shell/tools |
| `alpine:3.20` | ~8 MB | yes (`sh`) | **musl** | tiny + you want a shell; watch the musl trap |
| `gcr.io/distroless/*` | ~20 MB | **no** | glibc | production default: no shell, has certs + nonroot user |
| `scratch` | 0 | no | none | fully static binaries only (Go with `CGO_ENABLED=0`, Rust musl) |

Two traps worth calling out:

- **Alpine + native modules.** If you build native code against glibc and then run on Alpine (musl), it breaks — same family of error as §3. Keep the libc consistent from build to runtime.
- **Distroless has no shell.** Great for security (nothing to `exec` into), but you can't `docker exec … sh` to debug. Use the debugging method from §3 instead, or the `:debug` distroless variants during development.

### The interpreted-language case (Node)

Multi-stage still helps, but the shape is different — you're separating **dev dependencies + build tooling** from **production runtime**:

```dockerfile
# ---- deps: production node_modules only ----
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- build: needs dev deps to compile ----
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---- runtime ----
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps  /app/node_modules ./node_modules
COPY --from=build /app/dist         ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

Node's version of "builds but won't run":

- `Cannot find module 'express'` → forgot to copy `node_modules` into the runtime stage.
- Wrong `CMD` path (`server.js` vs `dist/server.js`).
- **Native addons** (`bcrypt`, `sharp`) built on Debian/glibc then copied into an Alpine/musl runtime → the addon fails to load. Same libc lesson as Go.

---

## 5 · Comparing sizes properly

Don't just eyeball `docker images` — teach students to *see where the weight is*.

**Overall size:**
```bash
docker images | grep shortlink
```

**Per-layer breakdown** — find the fat layer:
```bash
docker history shortlink:multi
```
Each row is a layer with its size. This is how you catch "why is there a 200 MB layer in my 'small' image?"

**Interactive exploration with `dive`:**
```bash
# install: https://github.com/wagoodman/dive
dive shortlink:multi
```
`dive` gives you a TUI showing every layer's contents and an **efficiency score** — it flags files that are added in one layer and deleted in another (wasted space that still counts toward image size).

**Total disk footprint:**
```bash
docker system df
```

**Have students fill in this table** as a lab deliverable:

| Image | Base | Size | # layers | CVEs (C/H) |
|---|---|---|---|---|
| `shortlink:naive` | `golang:1.23` | | | |
| `shortlink:multi` | `scratch` | | | |
| `shortlink:distroless` | `distroless/static` | | | |

Filling this in themselves makes the tradeoffs concrete.

---

## 6 · Caching — how it works and how it breaks

### How layer caching works

Each Dockerfile instruction produces a layer. Docker computes a cache key from the instruction **and** the files it touches. On rebuild, if the key is unchanged, Docker reuses the cached layer. **The moment one layer's key changes, that layer and *every layer after it* are rebuilt.** That last sentence is the whole mental model — order matters enormously.

### Mistake 1 — `COPY . .` before installing dependencies

```dockerfile
# BAD
COPY . .
RUN npm ci          # or: go mod download / pip install
```

Any source-code change alters the `COPY . .` layer, which busts the cache, which forces `npm ci` to run **every single build**. Dependencies rarely change; source changes constantly. So copy the *manifests* first:

```dockerfile
# GOOD — dependency install is cached until package files change
COPY package.json package-lock.json ./
RUN npm ci
COPY . .            # source last
```

Go equivalent (already in our §2 Dockerfile):
```dockerfile
COPY go.mod go.sum ./
RUN go mod download
COPY . .
```

**Principle: order instructions from least-frequently-changed to most-frequently-changed.**

### Mistake 2 — splitting `apt-get update` from `apt-get install`

```dockerfile
# BAD
RUN apt-get update
RUN apt-get install -y curl
```

The `update` layer gets cached. Weeks later you add a package; `update` is still cached (stale package index), so `install` runs against outdated metadata → "package not found" or you get old versions. Always combine them, and clean up in the same layer:

```dockerfile
# GOOD
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
```

(`--no-install-recommends` and the `rm` also shrink the layer — smaller *and* correct.)

### Mistake 3 — no `.dockerignore`

Without one, `COPY . .` sucks in `.git/`, `node_modules/`, local build output, logs — all of which change constantly and **bust your cache every build** (and bloat the build context you send to the daemon). Minimum viable `.dockerignore`:

```
.git
node_modules
dist
*.log
Dockerfile*
.env
```

### Mistake 4 — cache-busting `ARG`/`ENV` placed too high

```dockerfile
# BAD — invalidates everything below on every build
ARG BUILD_DATE
ENV BUILD_DATE=$BUILD_DATE
COPY go.mod go.sum ./
RUN go mod download
```

A value that changes every build (timestamp, commit SHA) placed early invalidates all subsequent layers. Put frequently-changing `ARG`/`ENV` **as late as possible**, after the expensive cached steps.

### Bonus — BuildKit cache mounts (mention, don't dwell)

BuildKit can persist a package cache *across* builds without baking it into a layer:

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=cache,target=/root/.npm  npm ci
RUN --mount=type=cache,target=/go/pkg/mod go build -o /server ./cmd/server
```

This keeps download caches warm even when the layer itself is invalidated. Good "next level" material once the basics land.

---

## 7 · Scanning for vulnerabilities

This ties the whole lesson together: **fewer packages → fewer CVEs.** A scan on `shortlink:naive` vs `shortlink:multi` makes that visible.

> Note: the old `docker scan` (Snyk-based) is deprecated. The current built-in is **`docker scout`**, bundled with Docker Desktop 4.17+. On Linux without Desktop, install the plugin:
> `curl -sSfL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --`

### Quick overview

```bash
docker scout quickview shortlink:naive
```

Gives a one-line severity summary (`C`ritical / `H`igh / `M`edium / `L`ow) for your image **and its base image**, plus base-image update suggestions. Run it on both images and watch the numbers collapse for the multi-stage one.

### Detailed CVE list

```bash
docker scout cves shortlink:naive
```

Useful filters for teaching and for CI:

```bash
# only the CVEs you'd actually block a release on
docker scout cves --only-severity critical,high shortlink:naive

# only ones that have a fix available (actionable)
docker scout cves --only-fixed shortlink:naive
```

### Recommendations (how to fix)

```bash
docker scout recommendations shortlink:naive
```

Suggests base-image refreshes/updates that reduce CVEs — e.g. "update `node:20.5` → `node:20.11-alpine`, fixes N vulnerabilities."

### Comparing two images

```bash
docker scout compare --to shortlink:multi shortlink:naive
```

### CI gate (fail the build on criticals)

```bash
docker scout cves --only-severity critical --exit-code shortlink:multi
# exit code 2 = vulnerabilities found → pipeline fails
```

### Alternative: Trivy (free, CI-friendly, no Docker Hub login)

```bash
trivy image shortlink:naive
trivy image --severity CRITICAL,HIGH shortlink:naive
trivy image --exit-code 1 --severity CRITICAL shortlink:multi   # CI gate
```

### Reading results

Point out three things in the output:

1. **Severity buckets** (C/H/M/L) — triage top-down.
2. **Fixable vs not** — a CVE with no available fix isn't something you can patch today; focus energy on `--only-fixed`.
3. **Base image vs app dependency** — a base-image CVE is fixed by updating the base; an app-dependency CVE is fixed by bumping *your* dependency. Scout tells you which is which.

The punchline: `shortlink:multi` on `scratch` has essentially **nothing to scan** — no OS packages means no OS CVEs. Security fell out of the size work for free.

---

## 8 · Hands-on lab

Give students the naive Go project and this sequence:

1. **Measure the baseline.** Build `Dockerfile.naive`, record size + `docker scout quickview`.
2. **Go multi-stage.** Write the two-stage Dockerfile targeting `scratch`. Build, run, confirm it serves on `:8080`.
3. **Break it on purpose.** Remove `CGO_ENABLED=0` *and* import something that triggers cgo (or just switch the final base to `alpine` with a glibc build). Reproduce `exec /server: no such file or directory`.
4. **Debug it** using the §3 method: run the builder stage, `ldd` the binary, identify static vs dynamic. Fix it.
5. **Try three bases** — `scratch`, `distroless/static`, `alpine` — and fill in the comparison table from §5.
6. **Break caching, then fix it.** Put `COPY . .` before `go mod download`, rebuild twice with a code change, watch deps re-download. Reorder, rebuild, watch it stay cached.
7. **Scan both** the naive and multi images. Record the CVE delta.

**Deliverable:** the completed comparison table + a one-paragraph writeup of what caused their "won't run" error and how they diagnosed it.

---

## Recap / cheat sheet

**Multi-stage:** build heavy, ship light. `COPY --from=<stage>` pulls only the artifact.

**`exec … no such file or directory` (file exists)** = missing loader/libc in the final stage → `CGO_ENABLED=0` for static, or use a matching-libc base. Never a mystery again.

**Debug "won't run":** read the exact error → run the *builder* stage to isolate → `ldd` to check static/dynamic → `inspect` the entrypoint.

**Caching:** least-changing layers first; copy dependency manifests before source; keep `apt update`+`install` in one `RUN`; use `.dockerignore`.

**Measure:** `docker images`, `docker history`, `dive`.

**Scan:** `docker scout quickview` / `cves` / `recommendations`, or `trivy image`. Smaller base = fewer CVEs.

```bash
# the four commands to leave on the board
docker history <image>                       # where's the weight?
docker build --target builder -t x:b .        # isolate build vs runtime
docker run --rm x:b ldd /server               # static or dynamic?
docker scout quickview <image>                # how exposed am I?
```


# Day 5 — Networking and Storage

**Slides:** How containers get on the network · Network drivers · Connecting by name · Containers forget everything · Volumes, bind mounts, tmpfs

Two problems today. How do two containers talk to each other? And how do you keep data when a
container is removed?

### Key ideas

- On a **user-defined network**, containers reach each other **by name** through Docker's
  built-in DNS, instead of by an IP address that changes on every restart.
- A container's writable layer is wiped when the container is removed. A **volume** is storage
  that lives outside the container, survives removal, and can be shared between containers. The
  rule: *code belongs in the image; data belongs in a volume.*

### Commands you'll use

`docker network create/ls`, `--network`, `docker volume create/ls`, `-v name:/path`, a bind
mount with `-v $(pwd):/path`, and `--tmpfs`.

### Steps

**5.1 — Reach a container by name**

```bash
docker network create appnet
docker run -d --name db --network appnet alpine sleep 3600
docker run --rm       --network appnet alpine getent hosts db
```

That last command resolved `db` to an IP by name — no IP address was ever hard-coded. In a
real app, your API would simply connect to `postgres://db:5432`.

**5.2 — Show that the default network can't do this**

```bash
docker run --rm alpine getent hosts db    # not on your network, so no name resolution
```

The default bridge has no name-based DNS. This is why you always create your own network.

**5.3 — Keep data with a volume**

```bash
docker volume create appdata
docker run --rm -v appdata:/out alpine sh -c 'echo "version 1" > /out/log.txt'
docker run --rm -v appdata:/out alpine cat /out/log.txt    # still there
```

The container that wrote the file is gone, but the file remains. That's a volume.

**5.4 — Lose data without one**

```bash
docker run --name tmp alpine sh -c 'echo secret > /tmp/note'
docker rm tmp
```

The file was on the writable layer, so removing the container destroyed it. Compare this with
5.3 — that contrast is the most important storage lesson of the week.

**5.5 — Edit files live with a bind mount**

```bash
mkdir -p ~/mysite && echo "<h1>edit me live</h1>" > ~/mysite/index.html
docker run -d --name live -p 8081:80 \
  -v ~/mysite:/usr/share/nginx/html:ro nginx:1.27
curl -s localhost:8081
echo "<h1>changed on the host</h1>" > ~/mysite/index.html
curl -s localhost:8081          # changes immediately, no rebuild
```

A bind mount maps a folder on the host straight into the container — useful while developing.

**5.6 — Memory-only storage with tmpfs**

```bash
docker run --rm --tmpfs /scratch:rw,size=16m alpine sh -c 'echo ram-only > /scratch/x; cat /scratch/x'
```

This never touches disk. It's for secrets and scratch data, and it disappears when the container
stops.

### If you finish early

From the network drivers table on the slides, write a one-line use case for each of `bridge`,
`host`, `none`, `overlay`, and `macvlan`. Then run `docker run --rm --network none alpine ip
addr` and confirm the container has no network.

### Check yourself

1. Why connect to another container by name instead of by IP?
2. You remove a database container. Was its data on the writable layer or a volume? How do you
   make sure it survives?
3. Volume, bind mount, tmpfs — give the one-line use case for each.

### Common mistake

Cleanup needs extra steps today. Removing your containers doesn't remove your network or volume
— those need `docker network rm appnet` and `docker volume rm appdata`. Left-behind volumes are
the quiet way a machine runs out of disk.

---

# Day 6 — Registries and Compose

**Slides:** Docker registry and Hub · Self-hosted registry and Harbor · Real apps are many containers · A compose file · Compose beyond the basics

Two skills: send an image to a registry so other machines can pull it, and run a whole
multi-container app from a single file.

### Key ideas

- A **registry** stores and serves images, addressed by `name:tag`. A **digest** (`@sha256:…`)
  locks the exact bytes, so it can't change underneath you.
- **Compose** describes a whole application — every service, network, and volume — in one YAML
  file. `docker compose up` starts the entire stack together, instead of many separate
  `docker run` commands in the right order.

### Commands you'll use

`docker tag/push/pull`, `docker login`, and `docker compose up -d / ps / down / logs / exec`.

### Steps

**6.1 — Run your own registry, then push to it**
You don't need a Docker Hub account for this — run a registry on your own machine (it's just
another container) and push to it. Keep it running through Day 7; you'll use it there too.

```bash
docker run -d -p 5000:5000 --name registry registry:2
docker tag  myapp:1 localhost:5000/myapp:1
docker push localhost:5000/myapp:1
```

**6.2 — Pull it back fresh**

```bash
docker rmi localhost:5000/myapp:1              # remove your LOCAL copy
docker run --rm localhost:5000/myapp:1 echo "pulled from the registry"
```

You deleted the local image and Docker fetched it from the registry. Your image now lives
somewhere portable, not just baked into your shell history.

**6.3 — Describe a whole stack in one file**
In `~/myapp`, create `compose.yaml`:

```yaml
services:
  web:
    build: .
    ports: ["8080:8000"]
    environment:
      GREETING: "served by the stack"
    depends_on: [cache]
  cache:
    image: redis:7-alpine
```

```bash
docker compose up -d
docker compose ps
curl -s localhost:8080
```

Compose creates a project (named after the folder) and a network for it automatically, which is
why `web` can reach `cache` by name.

**6.4 — Operate the stack**

```bash
docker compose up -d --scale web=3       # three copies of web, one command
docker compose logs --tail 20 web
docker compose exec cache redis-cli ping  # PONG
docker compose down                       # stops and removes the whole stack
```

### If you finish early

Add a `healthcheck` to the `cache` service, and make `web` depend on it with `condition:
service_healthy`. Show that `web` now waits until Redis is actually answering, not just started.

### Check yourself

1. What does a digest guarantee that a tag does not?
2. Inside a Compose project, how does `web` find `cache`? What did you not have to set up?
3. What's the difference between `docker compose down` and `docker compose stop`?

### Common mistake

`depends_on` controls start order only, not readiness. A database can be "started" but not yet
accepting connections. The fix is a `healthcheck` plus `condition: service_healthy`. Also: run
`docker compose down` at the end of every session so you don't leave stacks running.

---

# Day 7 — Pipelines and Orchestration

**Slides:** Deploy via a CI/CD pipeline · One host is not enough · Docker Swarm · Swarm vs Kubernetes · The Docker workflow

Everything connects today: build, ship, and run, automatically and at scale.

### Key ideas

- A **CI/CD pipeline** is just the commands you already know — build, test, scan, push, deploy —
  run automatically on every commit, with a gate in the middle. If the security scan finds a
  critical vulnerability, the build fails and nothing ships.
- An **orchestrator** keeps a target number of containers running across machines. You declare
  "I want three of these"; it schedules them, balances traffic, and restarts any that fail. You
  state the desired result, and it maintains it.

### Commands you'll use

`docker scout` or `trivy` with a fail-on-critical flag, a small shell script, and
`docker swarm init` and `docker service create/scale/update/ps`.

### Steps

**7.1 — Build the pipeline as a script**
A pipeline is these steps in order. Make sure your registry from Day 6 is still running
(`docker ps | grep registry`), then save this as `deploy.sh` in `~/myapp` and run it:

```bash
#!/usr/bin/env bash
set -euo pipefail
SHA=$(date +%s)                     # stands in for a git commit ID
REG=localhost:5000/myapp

echo "build";  docker build -t $REG:$SHA .
echo "test";   docker run --rm $REG:$SHA python -c "print('tests pass')"
echo "scan";   docker scout cves --exit-code --only-severity critical $REG:$SHA \
                 || { echo "critical vulnerabilities found — stopping, nothing ships"; exit 1; }
echo "push";   docker push $REG:$SHA
echo "deploy"; docker compose up -d
echo "shipped $REG:$SHA"
```

```bash
chmod +x deploy.sh && ./deploy.sh
```

The scan step is a gate: try pointing your Dockerfile at an old, vulnerable base image and watch
the deploy never run.

**7.2 — A self-healing cluster you run yourself**
On the shared machine this used to be a demo — but Docker turns your own machine into a
single-node cluster, so now you run it. (First `docker compose down` if your Day 6 stack is still
up, so port `9090` is free.)

```bash
docker swarm init
docker service create --name fleet --replicas 3 -p 9090:80 nginx:1.27
docker service ps fleet                       # three tasks scheduled

docker rm -f $(docker ps -q --filter name=fleet | head -1)   # kill one
docker service ps fleet                       # it's rescheduled automatically

docker service scale fleet=5                  # scale up
docker service update --image nginx:1.27 fleet  # rolling update
```

The key idea to take away: you declared three replicas; one was killed; it stayed three. You
state the desired result, and the orchestrator keeps it true.

When you're done, tear it all down:

```bash
docker service rm fleet
docker swarm leave --force
docker rm -f registry        # done with the local registry from Day 6
```

**7.3 — Swarm versus Kubernetes**
Using the slide's comparison: Swarm is built into Docker and simple to learn; Kubernetes is the
industry standard at scale, far more powerful, and harder to learn. The images you built this
week run unchanged on either one — orchestration changes how containers are managed, not what's
inside them.

**7.4 — Say the whole workflow from memory**
> Write a recipe (Dockerfile), build an image, ship it through a registry and a pipeline, run it
> anywhere — from a single container to a cluster.

If you can say that and explain each part, you've understood the module.

### If you finish early

Turn `deploy.sh` into a real `.github/workflows/deploy.yml`. Match each shell line to a workflow
step. You don't have to run it — translating it proves you understand what CI is doing.

### Check yourself

1. Why is the scan a *gate* rather than just a report?
2. When a container dies, what does the orchestrator actually do, and why?
3. Do your images need to change to run on Kubernetes? Why or why not?

### Common mistake

Thinking CI/CD is a separate, magical tool. It's the same `docker build`, `push`, and `run`
commands you already know, run automatically on every commit, with a scan as the gate.

---

## Where you are now

You can package an application into an image, make that image small and non-root, store and
share it through a registry, run a multi-container stack from one file, and put the whole thing
behind an automated pipeline that ships to a cluster.

The build–ship–run cycle is the same at every scale. Next up is Kubernetes, which runs these
exact images across many machines.
