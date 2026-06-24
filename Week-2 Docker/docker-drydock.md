# 🐳 Docker Drydock

### A 7-Day Gamified Voyage from Deckhand to Harbormaster

> *Build once. Ship anywhere. Run everywhere.*

A hands-on, drill-driven companion to the **Docker & Containers** deck. Where the slides
explain, the Drydock makes students **do** — every concept is earned by running a command
and watching something happen. Same spirit as Orbit Linux Dojo: analogies up front, a
toolbelt of commands, then drills that level you up. No boss battle this time.

---

## Why 7 days (and how to flex it)

The deck is 6 parts, but two of them carry a double load: **Dockerfile** (Part 3) is the
single highest-leverage skill in the whole module, and **Compose + CI/CD + Orchestration**
(Part 6) is really three topics wearing one trench coat. So the default plan splits Part 3
across two days and keeps the rest at one part per day.

| If you have… | Do this |
|---|---|
| **6 days (ideal)** | Merge **Day 3 + Day 4** into one fast "Build & Harden" day (skip the size-comparison side quests). |
| **7 days (recommended)** | Run as written below. |
| **8 days** | Split **Day 7** into *7a — CI/CD pipeline* and *7b — Orchestration & Swarm*. Gives the pipeline room to breathe. |

---

## How the game works

- **One rank per day.** Finish a day's core drills → you advance. Seven days, seven ranks.
- **XP per drill.** Each drill is worth XP. Core drills are mandatory; ⭐ **side quests** are
  for whoever finishes early (great for the inevitable spread in a class).
- **Captain's Log.** Each day ends with 3–4 self-check questions. If a student can answer
  them out loud, they earned the rank.
- **Common Wrecks.** Every day flags the mistake students *will* make, so you can pre-empt it.

### The rank ladder

| Day | Deck part | Rank earned | They can now… |
|---|---|---|---|
| 1 | Foundations | 🪢 **Deckhand** | explain what a container *is* and why it isn't a VM |
| 2 | Install & Operate | 📦 **Stevedore** | run, inspect, and tidy up containers by hand |
| 3 | Dockerfile | 🔨 **Shipwright** | write a Dockerfile that builds a working image |
| 4 | Image craft | ⚒️ **Master Shipwright** | make images small, fast, and non-root |
| 5 | Networking & Storage | ⚓ **Bosun** | wire containers together and keep data alive |
| 6 | Registries & Compose | 🗝️ **Quartermaster** | ship images to a registry and run a stack from one file |
| 7 | CI/CD & Orchestration | 🎖️ **Harbormaster** | push a stack through a pipeline and run a self-healing fleet |

---

## ⚠️ The Sandbox Protocol (read this before Day 1)

Your whole class shares **one Docker daemon on one VM**. The daemon does not isolate
*students* from each other — only containers from the host. Without rules, two students will
both try to grab port `8080`, name a container `web`, or run `docker system prune -a` and
delete everyone's images. So the first thing every student does, **every session**, is claim
an identity:

```bash
# ── Run once at the start of every session ──────────────────────────
export DKR=$USER                            # your prefix for EVERYTHING
export PB=$(( 20000 + (UID % 800) * 5 ))    # your 5 private ports: PB .. PB+4
export COMPOSE_PROJECT_NAME=$DKR            # namespaces all your compose resources
echo "Sailor: $DKR | Your ports: $PB–$((PB+4))"
```

**Three rules, posted on the wall:**

1. **Name everything after yourself.** `--name $DKR-web`, image tags `$DKR/app:1`,
   networks `$DKR-net`, volumes `$DKR-data`. And label it so you can find it:
   `--label owner=$DKR`.
2. **Use your own ports only** (`$PB` through `$PB+4`). Never publish to a port you weren't given.
3. **Only ever delete your own things.** The nuke command `docker system prune -a` and
   `docker rmi` on shared base images are **banned**. To clean up, use:
   ```bash
   docker rm -f $(docker ps -aq --filter "label=owner=$DKR") 2>/dev/null
   docker volume rm $DKR-data 2>/dev/null; docker network rm $DKR-net 2>/dev/null
   ```

> 💡 *If the VM supports it, rootless Docker per student is the cleaner long-term answer (deck,
> "Install & configure"). For a 7-day bootcamp, the prefix convention above is enough and
> teaches good hygiene anyway.*

---

# 🪢 Day 1 — Foundations → *Deckhand*

> **Deck:** Why containers · What a container is · Containers vs VMs · The ecosystem · Architecture

### Mission briefing
A shipping container changed the world not because it was clever, but because it was
*standardised*: the same steel box rides a truck, a crane, a train, and a ship without anyone
unpacking it. A software container is that box for your app. Today you don't build anything —
you prove to yourself that the box is real.

### Core mental models
- **Container = a standardised shipping container.** Your app + its libraries, sealed, runs
  identically on any host with a runtime.
- **The kernel = the port's shared infrastructure.** Every container ship docks at the *same*
  port (the host kernel). A VM, by contrast, brings its *own entire port* with it — that's the
  guest OS, and it's why VMs are measured in gigabytes and containers in megabytes.
- **Namespaces = the walls of your container; cgroups = the weight limit on your cargo.**

### Toolbelt
`docker run` · `docker version` · `docker info` · `uname -r` · `ps` · flags `--rm`, `--memory`, `--cpus`

### Drills

**1.1 — First contact (10 XP)**
```bash
docker run --rm hello-world
```
Read every line of the output. Then narrate the journey out loud: the **client** sent a
command → the **daemon** didn't have the image → it **pulled** from Docker Hub → **created** a
container → **ran** it → it printed and exited. That sentence *is* the architecture slide.

**1.2 — Prove the shared kernel (15 XP)**
```bash
uname -r                              # the host kernel
docker run --rm alpine uname -r       # the container's kernel
```
They're **identical**. There is no guest OS inside. This is the one fact that separates a
container from a VM — make them say it back to you.

**1.3 — See the isolation (15 XP)**
```bash
docker run --rm alpine ps aux         # the container sees only its own processes
ps aux | head                         # the host sees hundreds
```
Same kernel, totally different *view*. That different view is a **namespace**.

**1.4 — Feel the cgroup (15 XP)**
```bash
docker run --rm --memory=64m alpine sh -c 'echo "I am capped at 64MB of RAM"'
docker run --rm --cpus=0.5 alpine sh -c 'echo "I am capped at half a CPU"'
```
Namespaces decide *what you can see*; cgroups decide *how much you can take*.

**1.5 — The runtime stack (10 XP, discussion)**
Run `docker info | grep -i runtime`. You'll see `runc`. Walk the ladder from the deck:
your `docker` CLI → `dockerd` → `containerd` → `runc` → the kernel. Ask: *"Kubernetes dropped
Docker as a runtime — do your images still work?"* (Yes — they're OCI images; k8s just talks
to containerd directly.)

> ⭐ **Side quest (20 XP):** Run `docker run --rm -it alpine sh`, then inside try
> `cat /etc/os-release`. You're "in Alpine" on an Ubuntu host. Explain how that's possible with
> *one shared kernel*. (Hint: it's just a different userland filesystem — the box, not the engine.)

### Captain's Log
1. In one sentence, why does a container start in milliseconds but a VM in seconds?
2. What does a VM have that a container deliberately doesn't?
3. Which kernel features make isolation possible, and which one limits resources?

### Common Wreck
Students say "a container is a lightweight VM." Kill this on Day 1. A VM **virtualises
hardware**; a container **isolates a process**. No shared kernel = not a container.

---

# 📦 Day 2 — Install & Operate → *Stevedore*

> **Deck:** Installing Docker · Image → Container · The lifecycle · `docker run` · Publishing ports · Inspect & clean up

### Mission briefing
A stevedore is the person on the dock who actually loads and unloads the ships. Today you stop
watching and start operating: pull a blueprint, launch a ship from it, send it cargo on a
port, look inside it, and scrap it cleanly.

### Core mental models
- **Image = the blueprint; container = the ship built from it.** (Deck: *image is the class,
  container is the object; image is the recipe, container is the dish.*) One blueprint →
  as many ships as you want.
- **The writable layer = a whiteboard bolted to the ship.** Anything you scribble on it is
  gone the moment the ship is scrapped. (We fix this on Day 5.)
- **Publishing a port = opening a gangway** from the dock (`host`) to the ship (`container`).
  No `-p`, no gangway, no visitors.

### Toolbelt
`docker pull` · `docker images` · `docker run` (`-d --name -p -e -v -it --rm`) · `docker ps -a`
· `docker logs -f` · `docker exec -it` · `docker stop/start/pause/unpause` · `docker rm/rmi`

### Drills

**2.1 — Pull a pinned blueprint (10 XP)**
```bash
docker pull nginx:1.27       # pin the tag — never trust :latest in a classroom
docker images | grep nginx
```
Ask why `:1.27` and not `:latest`. (`latest` moves under your feet; reproducibility dies.)

**2.2 — Launch your ship (20 XP)**
```bash
docker run -d --name $DKR-web -p $PB:80 --label owner=$DKR nginx:1.27
curl -s localhost:$PB | head -n 4
```
You just published port `$PB` → container `80`. The gangway is open. (Note: this is *your*
port from the Sandbox Protocol — no collisions.)

**2.3 — Walk the lifecycle (20 XP)**
```bash
docker pause  $DKR-web && docker ps      # note the (Paused) state
docker unpause $DKR-web
docker stop   $DKR-web && docker ps -a   # gone from `ps`, still in `ps -a`
docker start  $DKR-web
```
Map each command onto the lifecycle diagram from the deck: Created → Running → Paused →
Stopped → Removed.

**2.4 — Board the ship (15 XP)**
```bash
docker exec -it $DKR-web bash
# inside: ls /usr/share/nginx/html ; cat /etc/nginx/nginx.conf ; exit
docker logs --tail 5 $DKR-web
```
`exec` opens a shell *inside a running* container. `logs` streams what it prints.

**2.5 — One blueprint, three ships (15 XP)**
```bash
for n in 1 2 3; do
  docker run -d --name $DKR-web-$n -p $((PB+n)):80 --label owner=$DKR nginx:1.27
done
docker ps --filter "label=owner=$DKR"
```
Three identical ships from one image — this is the *scaling* idea, by hand, before Compose
does it for you.

**2.6 — Scrap cleanly (15 XP)**
```bash
docker rm -f $(docker ps -aq --filter "label=owner=$DKR")
docker ps -a --filter "label=owner=$DKR"     # empty = good sailor
```
Notice you removed **only your own** containers. This is the muscle memory the Sandbox Protocol
is building.

> ⭐ **Side quest (20 XP):** Run a throwaway interactive box: `docker run -it --rm ubuntu bash`.
> Install something, make a mess, `exit`. Prove with `docker ps -a` that `--rm` left nothing
> behind. Then explain when you'd want that vs `-d`.

### Captain's Log
1. What three things does `docker run` do in sequence?
2. A stopped container still costs you something — what, and how do you reclaim it?
3. `-p 8080:80` — which number is the host and which is the container?

### Common Wreck
`EXPOSE` in a Dockerfile does **not** publish a port — only `-p` does. And students forget
that `docker stop && docker rm` leaves the *image* on disk; removing the image is `docker rmi`.

---

# 🔨 Day 3 — Build Images with Dockerfile → *Shipwright*

> **Deck:** Hand-built containers don't scale · Anatomy of a Dockerfile · Instructions reference · CMD vs ENTRYPOINT

### Mission briefing
Up to now you've sailed ships other people built. A shipwright builds them — and writes down
exactly how, so anyone can rebuild the same ship. `docker commit` is building a ship by hand
with no plans: it floats, but nobody can ever reproduce it. A **Dockerfile** is the plan.

> **The shipwright's creed (deck):** *If it isn't in the Dockerfile, it doesn't exist.*

### Core mental models
- **Dockerfile = the build plan**, lives in git, reviewed and diffable.
- **`CMD` = the default order you shout** as the ship leaves; easy to override.
  **`ENTRYPOINT` = the engine that always runs**; `CMD`/CLI args are just fuel appended to it.

### Toolbelt
`docker build -t` · `FROM WORKDIR COPY RUN ENV EXPOSE USER CMD ENTRYPOINT` · `.dockerignore`

### Sample app (no internet required)
To keep this runnable on a locked-down shared VM, the starter app uses Python's **standard
library only** — no `pip install`, no network. Create a folder `~/$DKR-app`:

```python
# server.py
import http.server, os
port = int(os.environ.get("PORT", "8000"))
msg  = os.environ.get("GREETING", "Hello from the Drydock")
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(f"{msg} (port {port})\n".encode())
print(f"serving on {port}")
http.server.HTTPServer(("", port), H).serve_forever()
```

> *Have a working internet mirror? Swap in a Node/Flask app to also demonstrate `RUN npm ci` /
> `RUN pip install` and dependency-layer caching — that's a richer Day 4 cache lesson.*

### Drills

**3.1 — Your first blueprint (25 XP)**
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
cd ~/$DKR-app
docker build -t $DKR/app:1 .
docker run -d --name $DKR-app -p $PB:8000 --label owner=$DKR $DKR/app:1
curl -s localhost:$PB
```
You wrote a recipe and built an image from scratch. Read the build output — each line is a
**layer** (we exploit that tomorrow).

**3.2 — `.dockerignore` (15 XP)**
```bash
echo -e ".git\n__pycache__\n*.log\nREADME.md" > .dockerignore
```
Explain: the build *context* is everything in the folder, shipped to the daemon. Junk and
secrets do not belong in it.

**3.3 — Override the order (`CMD`) (15 XP)**
```bash
docker run --rm -e GREETING="Custom order" $DKR/app:1          # uses CMD
docker run --rm $DKR/app:1 python -c "print('I replaced the CMD entirely')"
```
The second run *replaced* `CMD`. That's how easy `CMD` is to override.

**3.4 — `ENTRYPOINT` vs `CMD` (25 XP)**
Build a second variant that pins the executable:
```dockerfile
# Dockerfile.entry
FROM python:3.12-slim
WORKDIR /app
COPY server.py .
ENTRYPOINT ["python", "server.py"]
CMD []
```
```bash
docker build -f Dockerfile.entry -t $DKR/app:entry .
docker run --rm $DKR/app:entry echo hi    # try to override — note it CANNOT, python still runs
```
With `ENTRYPOINT`, `echo hi` becomes *arguments to python*, not a replacement. Walk the deck's
example: `ENTRYPOINT ["python","app.py"]` + `CMD ["--port","8000"]` → run with no args gives
`--port 8000`; run with `--port 9000` swaps the default.

**3.5 — Drop to non-root (20 XP)**
```dockerfile
# add before CMD:
RUN useradd -m sailor
USER sailor
```
Rebuild, then:
```bash
docker run --rm $DKR/app:1 whoami     # should print: sailor, not root
```
Never run as root inside a container if you can avoid it (we'll harden more on Day 4).

> ⭐ **Side quest (25 XP):** Break the build on purpose — reference a file that isn't there in a
> `COPY`. Read the error. Fix it. Knowing how to read a failed build is half the skill.

### Captain's Log
1. Why is a Dockerfile better than `docker commit`?
2. You want users to be able to swap the command easily → `CMD` or `ENTRYPOINT`?
3. What is the "build context," and why does `.dockerignore` matter for it?

### Common Wreck
The **shell form** vs **exec form** of `CMD`/`ENTRYPOINT`. `CMD python server.py` (shell form)
wraps in `/bin/sh -c` and breaks signal handling; `CMD ["python","server.py"]` (exec form) is
correct. Always teach the JSON-array exec form.

---

# ⚒️ Day 4 — Image Craft → *Master Shipwright*

> **Deck:** Layers & the build cache · Best practices · Multi-stage builds · Security hardening

### Mission briefing
Anyone can build a ship. A master shipwright builds one that's **light, fast to rebuild, and
safe**. Today is about the build cache (speed), multi-stage builds (size), and hardening
(safety). The "aha" moment is watching a 1 GB image become 15 MB.

### Core mental models
- **Layers = stacked cargo pallets.** Each instruction is a pallet. Change a low pallet and
  *every pallet above it must be re-stacked* — that's a cache bust cascading.
- **The golden ordering: deps before source.** Copy your dependency manifest and install
  *first*; copy your changing source code *last*. Then editing code never re-runs the install.
- **Multi-stage = build in the workshop, ship only the finished part.** Compile in a fat image,
  copy just the binary into a tiny one.

### Toolbelt
`docker build` (watch `CACHED`) · multi-stage `FROM ... AS build` + `COPY --from=build` ·
`docker images` (compare `SIZE`) · `docker scout` / `trivy` (if installed) · `time`

### Drills

**4.1 — Watch the cache (20 XP)**
```bash
docker build -t $DKR/app:1 .         # first build: every step runs
docker build -t $DKR/app:1 .         # again, no changes: every step says CACHED
touch server.py                       # "edit" the source
docker build -t $DKR/app:1 .         # only the COPY layer and below rebuild
```
Make them *see* the word `CACHED` appear and disappear. This is why build order matters.

**4.2 — Bust the cache the wrong way (15 XP)**
Move `COPY server.py .` to be the *first* line after `FROM`. Rebuild twice with a code edit in
between. Now even unrelated steps rebuild. Lesson: **rarely-changing steps go first.**

**4.3 — The size reveal: multi-stage (30 XP)**
Use a compiled language so the win is dramatic. A tiny Go program is ideal:
```dockerfile
# Dockerfile.multi
FROM golang:1.22 AS build
WORKDIR /src
COPY main.go .
RUN go build -o app main.go

FROM gcr.io/distroless/static
COPY --from=build /src/app /app
USER nonroot
ENTRYPOINT ["/app"]
```
```go
// main.go
package main
import ("fmt";"net/http")
func main(){ http.HandleFunc("/",func(w http.ResponseWriter,_*http.Request){fmt.Fprintln(w,"tiny ship")}); http.ListenAndServe(":8000",nil) }
```
```bash
docker build -f Dockerfile.multi -t $DKR/tiny:1 .
docker images | grep -E "golang|$DKR/tiny"     # compare ~800MB builder vs ~10MB final
```
The final image carries *only the binary* — no compiler, no shell, no OS clutter. That gap is
the whole point of multi-stage. *(If Go isn't on the VM, demo the size table from the deck and
compare `python:3.12` vs `python:3.12-slim` vs `python:3.12-alpine` with `docker images`.)*

**4.4 — Base image diet (15 XP)**
```bash
docker pull python:3.12 ; docker pull python:3.12-slim ; docker pull python:3.12-alpine
docker images | grep python
```
Same language, wildly different sizes. Fewer packages = smaller image = smaller attack surface.

**4.5 — Scan for CVEs (20 XP, if tooling available)**
```bash
docker scout cves $DKR/app:1          # or: trivy image $DKR/app:1
```
Find a vulnerability, then rebuild on a patched base and rescan. This is the exact gate the
CI/CD pipeline uses on Day 7.

> ⭐ **Side quest (25 XP):** Take your Day 3 Python image and shrink it as far as you can —
> `-slim` base, `.dockerignore`, non-root `USER`, combined `RUN` steps. Post your final
> `docker images` size to the class channel. Smallest working image wins.

### Captain's Log
1. You changed one line of source — why did the dependency install *not* re-run (if your
   Dockerfile is ordered well)?
2. What does a multi-stage build leave *out* of the final image, and why does that matter?
3. Name three things from the security slide you'd check before shipping an image.

### Common Wreck
Students `COPY . .` at the top "to be safe," which busts the cache on every code change and
balloons rebuild times. Order is everything: **manifests → install → source, last.**

---

# ⚓ Day 5 — Networking & Storage → *Bosun*

> **Deck:** How containers get on the network · Network drivers · Connecting by name · Containers forget everything · Volumes, bind mounts & tmpfs

### Mission briefing
The bosun runs the deck: the lines that connect things, and the hold where cargo is stored.
Two problems today. First: how do two ships talk *to each other* without memorising
coordinates? Second: when you scrap a ship, how do you not lose its cargo?

### Core mental models
- **A user-defined bridge = a private radio channel** where ships hail each other **by name**
  (built-in DNS), never by a coordinate (IP) that changes every reboot.
- **The writable layer = the whiteboard** (wiped on scrap). **A volume = the warehouse on
  shore** — it outlives any single ship, and ships can share it.
- **Deck's law:** *Code belongs in the image; data belongs in a volume.*

### Toolbelt
`docker network create/ls` · `--network` · `docker volume create/ls` · `-v name:/path` ·
bind mount `-v $(pwd):/path` · `--tmpfs`

### Drills

**5.1 — Hail by name (25 XP)**
```bash
docker network create $DKR-net
docker run -d --name $DKR-db  --network $DKR-net --label owner=$DKR alpine sleep 3600
docker run --rm     --network $DKR-net alpine getent hosts $DKR-db
```
That last line resolves `$DKR-db` to an IP *by name* — Docker's built-in DNS on a user-defined
network. No IP was ever hard-coded. (In a real stack the API would just use
`postgres://$DKR-db:5432`.)

**5.2 — Prove the default bridge can't (15 XP)**
```bash
docker run --rm alpine getent hosts $DKR-db    # NOT on your network → no resolution
```
The default bridge has no name-based DNS. This is *why* the deck says: always make a
user-defined bridge.

**5.3 — Cargo that survives (25 XP)**
```bash
docker volume create $DKR-data
docker run --rm -v $DKR-data:/out alpine sh -c 'echo "manifest v1" > /out/log.txt'
docker run --rm -v $DKR-data:/out alpine cat /out/log.txt    # survives, even though the first container is gone
```
The container that *wrote* the file no longer exists, yet the data is still there. That's a
volume — the warehouse on shore.

**5.4 — Lose cargo on purpose (15 XP)**
```bash
docker run --name $DKR-tmp alpine sh -c 'echo secret > /tmp/note'
docker rm $DKR-tmp
# the file lived on the writable layer — it's gone with the container
```
Contrast 5.3 and 5.4 side by side. This is the single most important storage lesson.

**5.5 — Live-edit with a bind mount (20 XP)**
```bash
mkdir -p ~/$DKR-site && echo "<h1>edit me live</h1>" > ~/$DKR-site/index.html
docker run -d --name $DKR-live -p $((PB+1)):80 --label owner=$DKR \
  -v ~/$DKR-site:/usr/share/nginx/html:ro nginx:1.27
curl -s localhost:$((PB+1))
echo "<h1>changed on the host</h1>" > ~/$DKR-site/index.html
curl -s localhost:$((PB+1))          # changed instantly, no rebuild — great for dev
```

**5.6 — tmpfs: written on water (10 XP)**
```bash
docker run --rm --tmpfs /scratch:rw,size=16m alpine sh -c 'echo ram-only > /scratch/x; cat /scratch/x'
```
In-memory only, never touches disk — for secrets and scratch. Vanishes when the container stops.

> ⭐ **Side quest (20 XP):** From the deck's driver table, explain *in one line each* when you'd
> reach for `bridge`, `host`, `none`, `overlay`, `macvlan`. Then run a container with
> `--network none` and prove it has no connectivity (`docker run --rm --network none alpine ip addr`).

### Captain's Log
1. Why hail another container by name instead of by IP?
2. You `docker rm` a Postgres container — was your data on the writable layer or a volume? How
   do you guarantee it survives?
3. Volume vs bind mount vs tmpfs — give the one-line use case for each.

### Common Wreck
Cleanup needs an extra step today: `docker rm -f` your containers **and** `docker network rm
$DKR-net` **and** `docker volume rm $DKR-data`. Named volumes and networks don't disappear with
the container — leftover volumes are the #1 way a shared VM quietly fills its disk.

---

# 🗝️ Day 6 — Registries & Compose → *Quartermaster*

> **Deck:** Docker registry & Hub · Self-hosted registry & Harbor · Real apps are many containers · A compose file · Compose beyond the basics

### Mission briefing
The quartermaster manages the stores: where every blueprint is catalogued so any port can pull
it, and the single manifest that loads a whole fleet at once. Two skills: **ship an image to a
registry**, and **run a multi-container stack from one file.**

### Core mental models
- **Registry = the warehouse of blueprints**, addressed by `name:tag`. The **digest
  (`@sha256:…`) = a tamper-proof seal** locking the exact bytes.
- **Compose = the cargo manifest.** Doing it by hand is shouting individual `docker run`
  orders in the right sequence; Compose is one file that brings the whole stack up together.

> **Classroom registry:** rather than Docker Hub (accounts + anonymous pull rate limits), run
> **one** local `registry:2` for the class — `docker run -d -p 5000:5000 --restart always
> --name classroom-registry registry:2` (instructor does this once). Students push to
> `localhost:5000/$DKR/...`. No accounts, no rate limits.

### Toolbelt
`docker tag/push/pull` · `docker login` · `registry:2` · `docker compose up -d/ps/down/logs/exec`
· `COMPOSE_PROJECT_NAME`

### Drills

**6.1 — Catalogue your blueprint (20 XP)**
```bash
docker tag  $DKR/app:1 localhost:5000/$DKR/app:1
docker push localhost:5000/$DKR/app:1          # note the sha256 digest it prints — that's the seal
```

**6.2 — Pull it back from the warehouse (15 XP)**
```bash
docker rmi localhost:5000/$DKR/app:1           # delete your LOCAL copy
docker run --rm localhost:5000/$DKR/app:1 echo "pulled fresh from the registry"
```
You removed the local image and Docker fetched it from the registry — proving the image now
lives somewhere portable, not just on your laptop.

**6.3 — The manifest for a whole stack (30 XP)**
In `~/$DKR-app`, write `compose.yaml`:
```yaml
services:
  web:
    build: .
    ports: ["${PB}:8000"]
    environment:
      GREETING: "served by the fleet"
    depends_on: [cache]
  cache:
    image: redis:7-alpine
volumes: {}
```
```bash
PB=$PB docker compose up -d
docker compose ps
curl -s localhost:$PB
```
Because you set `COMPOSE_PROJECT_NAME=$DKR` in the Sandbox Protocol, every container, network,
and default volume is prefixed with your name — **zero collisions** with classmates. Point this
out: Compose gives each project its own network automatically, so `web` reaches `cache` by name.

**6.4 — Scale and operate the fleet (20 XP)**
```bash
docker compose up -d --scale web=3       # three web replicas, one command
docker compose logs --tail 20 web
docker compose exec cache redis-cli ping  # PONG
docker compose down                       # tears down the whole stack cleanly
```
Remember Day 2, when you ran three nginx ships by hand with a `for` loop? Compose just did it,
declaratively, and will clean it all up with one `down`.

> ⭐ **Side quest (25 XP):** Add a `healthcheck` to the `cache` service and make `web`
> `depends_on` it `condition: service_healthy`. Show that `web` now waits until Redis is
> *actually answering*, not just *started*. (This is the deck's "started ≠ ready" point.)

### Captain's Log
1. What does an image **digest** guarantee that a **tag** does not?
2. Inside a Compose project, how does `web` find `cache`? What did you *not* have to configure?
3. What's the difference between `docker compose down` and `docker compose stop`?

### Common Wreck
`depends_on` only controls **start order**, not **readiness** — the database can be "started"
but not yet accepting connections. The fix is a `healthcheck` + `condition: service_healthy`.
Also: students forget `down` and leave stacks running; teach `docker compose down` as the
period at the end of every session.

---

# 🎖️ Day 7 — CI/CD & Orchestration → *Harbormaster*

> **Deck:** Deploy via a CI/CD pipeline · One host is not enough · Docker Swarm · Swarm vs Kubernetes · The Docker workflow

### Mission briefing
The harbormaster doesn't load ships — they keep the *whole harbour* running: every blueprint
that arrives is inspected before it's allowed in (the pipeline), and a target number of ships
is always kept at sea, automatically replacing any that sink (orchestration). Today you connect
everything: **Build → Ship → Run**, at scale.

### Core mental models
- **A pipeline = the harbour's inspection gate.** Commit → build → test → **scan** → push →
  deploy. The scan is a *gate*: a critical CVE fails the build and the ship never sails.
- **An orchestrator = the harbormaster.** You declare "I want 3 of these running"; it
  *schedules* them across machines, *load-balances* traffic, and *self-heals* — a ship sinks,
  another is dispatched without you lifting a finger.

### Toolbelt
`trivy image --exit-code 1` / `docker scout` · a shell pipeline script · `docker swarm init` ·
`docker service create/scale/update/ps`

### Drills

**7.1 — Build the pipeline by hand (30 XP)**
A CI pipeline is just these steps run in order. Put them in `deploy.sh` and run it — this *is*
the deck's GitHub Actions excerpt, minus the YAML:
```bash
#!/usr/bin/env bash
set -euo pipefail
SHA=$(date +%s)                     # stand-in for the git commit SHA
REG=localhost:5000/$DKR/app

echo "▶ build";  docker build -t $REG:$SHA .
echo "▶ test";   docker run --rm $REG:$SHA python -c "print('tests pass')"
echo "▶ scan";   docker scout cves --exit-code --only-severity critical $REG:$SHA \
                   || { echo "✗ critical CVEs — pipeline FAILS, nothing ships"; exit 1; }
echo "▶ push";   docker push $REG:$SHA
echo "▶ deploy"; SHA=$SHA docker compose up -d
echo "✓ shipped $REG:$SHA"
```
The lesson: CI/CD isn't magic, it's *discipline expressed as a script*. The scan step is a
**gate** — make them break it (point at a vulnerable base image) and watch the deploy never run.
*(If `docker scout`/`trivy` isn't installed, replace the scan line with a placeholder `echo` and
explain where the real gate goes.)*

**7.2 — Run a self-healing fleet (35 XP — instructor-led demo)**
> ⚠️ **Shared-VM note:** a host can run **one** Swarm. So this is an **instructor demo on the
> projector**, not a per-student drill. (Per-student Swarm needs one VM each, or a managed
> multi-node lab.)

```bash
docker swarm init
docker service create --name fleet --replicas 3 -p 8080:80 nginx:1.27
docker service ls
docker service ps fleet                       # 3 tasks scheduled

# self-healing: kill a task and watch it come back
docker rm -f $(docker ps -q --filter name=fleet | head -1)
docker service ps fleet                       # the dead task is rescheduled automatically

# scale and roll
docker service scale fleet=5
docker service update --image nginx:1.27 fleet   # rolling update, then could --rollback

docker service rm fleet && docker swarm leave --force
```
Narrate it as the harbourmaster's job: *you declared 3, one sank, it stayed 3.* That single
sentence — **declare desired state, the orchestrator maintains it** — is the gateway to
Kubernetes.

**7.3 — Swarm vs Kubernetes (15 XP, discussion)**
Use the deck's table. Land the key reassurance: **the images you built this week run unchanged
on Kubernetes.** Swarm is the gentle on-ramp; k8s is the industry standard at scale — and the
next module.

**7.4 — The whole voyage in one breath (20 XP)**
Have each student narrate, from memory, the **Build → Ship → Run** recap from the final slide:
> *Write a recipe (Dockerfile), build an image, ship it through a registry and a pipeline, run
> it anywhere — from one container to a cluster.*

If they can say that and mean every word, they're a Harbormaster.

> ⭐ **Side quest (25 XP):** Turn `deploy.sh` into a real `.github/workflows/deploy.yml`. Map
> each shell line to a workflow step. (They don't have to run it — translating it proves they
> understand what CI is doing.)

### Captain's Log
1. Why is the **scan** step a *gate* and not just a report?
2. "Declare desired state" — what does an orchestrator actually do when a container dies?
3. Do your Docker images need changing to run on Kubernetes? Why or why not?

### Common Wreck
Students think CI/CD is a special tool. It's not — it's the same `docker build / push / run`
commands they already know, run automatically on every commit, *with a gate in the middle*.
And: Swarm is **one per host** — don't let 30 students try to `swarm init` on the shared VM.

---

## 🏁 Voyage complete

```
🪢 Deckhand → 📦 Stevedore → 🔨 Shipwright → ⚒️ Master Shipwright → ⚓ Bosun → 🗝️ Quartermaster → 🎖️ Harbormaster
```

A Harbormaster can package any app, harden it, ship it through a registry and a pipeline, and
run it anywhere — reproducibly, from one container to a fleet.

**Up next:** Kubernetes — orchestration at scale. Same containers underneath.

---

## 📋 Instructor quick reference

**Daily rhythm (≈2–2.5 hrs):** 20 min recap of yesterday's Captain's Log → 25 min teach the
day's slides → 60–75 min drills (you float and unstick) → 15 min side quests + Captain's Log.

**Pre-flight checklist (instructor, before Day 1):**
- Docker Engine installed; every student in the `docker` group (remember: **`docker` group =
  root** — fine for a classroom, but say it out loud).
- Pre-pull the shared base images so 30 students don't pull `nginx:1.27` / `python:3.12-slim` /
  `redis:7-alpine` / `alpine` simultaneously: `for i in nginx:1.27 python:3.12-slim redis:7-alpine alpine golang:1.22; do docker pull $i; done`.
- Start the classroom registry once (Day 6): `docker run -d -p 5000:5000 --restart always --name classroom-registry registry:2`.
- Post the **Sandbox Protocol** on the wall / pinned in chat.

**Disk hygiene:** the shared VM's disk is the thing that will bite you. End each day with a
class-wide reminder to run their own namespaced cleanup. Once a day *you* (not students) can
reclaim orphaned junk safely — but never during a session.

**XP totals (core, excluding side quests):** D1 65 · D2 95 · D3 100 · D4 100 · D5 110 · D6 85 ·
D7 100. Round numbers; tune to taste. Consider a small leaderboard for side-quest XP only — it
rewards the fast finishers without punishing the steady ones.
