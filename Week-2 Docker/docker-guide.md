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

**Slides:** Layers and the build cache · Best practices · Multi-stage builds · Security hardening

Anyone can build an image. Today you make one that rebuilds quickly, stays small, and doesn't
run as root.

### Key ideas

- Each instruction adds a **layer**, stacked like pallets. Change a lower pallet and every
  pallet above it has to be re-stacked — that's a cache miss cascading down.
- So the ordering rule is: **install dependencies first, copy your changing source code last.**
  Then editing your code never forces the slow dependency install to run again.
- A **multi-stage build** compiles in a big image but ships only the finished artifact in a tiny
  one.



**4.4 — Compare base image sizes**

```bash
docker pull python:3.12 ; docker pull python:3.12-slim ; docker pull python:3.12-alpine
docker images | grep python
```

Same language, very different sizes. Fewer packages means a smaller image and a smaller attack
surface.

**4.5 — Scan for vulnerabilities**

```bash
docker scout cves myapp:1          # or: trivy image myapp:1
```

This needs `docker scout` (bundled with recent Docker installs) or `trivy`. If you have neither,
read along and come back to it. Find a reported vulnerability, rebuild on an updated base image,
and scan again. This is exactly the check a real pipeline runs before shipping (you'll see it on
Day 7).

### If you finish early

Take your Day 3 Python image and shrink it as far as you can: a `-slim` base, a `.dockerignore`,
a non-root `USER`, and combined `RUN` steps. Compare your final `docker images` size with where
you started.

### Check yourself

1. You changed one line of source. Why did the dependency install *not* run again (assuming your
   Dockerfile is ordered well)?
2. What does a multi-stage build leave out of the final image, and why is that good?
3. Name three things from the security slide you'd check before shipping an image.

### Common mistake

Putting `COPY . .` near the top "to be safe." It busts the cache on every code change and makes
rebuilds slow. The order is: dependency files, then install, then the rest of the source last.

---

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
