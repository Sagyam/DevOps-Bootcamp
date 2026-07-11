# The example pipelines (and how to read them)

Each folder under `jobs/` is a ready-made pipeline job, seeded into Jenkins on
boot. After `docker compose up --build`, they all appear on the dashboard. Click
one → **Build Now** → watch the stage view.

Two flavours exist in Jenkins, and it helps to know which you're looking at:
- **Declarative** (`pipeline { ... }`) — structured, opinionated, easiest to read.
  Most examples here are declarative.
- **Scripted** (`node { ... }`) — raw Groovy, maximum flexibility. See
  `scripted-groovy`.

## The examples, easiest first

### `hello-ci`
The baseline: four linear stages. Start here to confirm everything runs.

### `params-and-approval`
Shows **parameters** (a dropdown, a text box, a checkbox), a **conditional
stage** (`when { expression { ... } }`), and a **manual approval gate**
(`input`) that only appears when you pick `prod`. Build it with **Build with
Parameters**.

> Jenkins quirk worth teaching: parameters only take effect from the *second*
> run onward. The first run registers them; run it once, then "Build with
> Parameters" appears.

### `parallel-and-matrix`
Two ideas back to back: three stages running **in parallel**, then a **matrix**
that fans one stage out across a 2×2 grid (platform × arch). The stage view makes
the fan-out visually obvious — a good "aha" for students.

### `resilient-pipeline`
Real-world hardening: `retry(3)` around a deliberately flaky step (it fails ~half
the time, so you'll see the retry actually save the build), a `timeout`, and a
`post { success / failure / always }` block. This is the pattern for
notifications and cleanup.

### `scripted-groovy`
The scripted style. Lists, a loop over services, a `try/catch` that swallows a
failure, and a computed value. Use it to show *why* scripted exists: when you
need real programming, not just structure.

### `docker-agent`  (advanced — needs Docker)
Runs a single stage **inside an ephemeral `node:22-alpine` container** that is
created for the stage and thrown away after. This is the killer Jenkins feature
for clean, tool-isolated builds.
**It only works if the Jenkins controller can reach a Docker daemon.** By
default this playground has none, so this job will fail with a Docker error —
that's expected. To make it work, mount the host Docker socket into the
container (uncomment the relevant lines in `docker-compose.yml`, add
`- /var/run/docker.sock:/var/run/docker.sock`) — note the security caveats of
doing so.

## Plugins worth having (all pre-installed here)

The "make life easy" set in `plugins.txt`:

| Plugin | Why you want it |
| --- | --- |
| `docker-workflow` | `agent { docker { image '...' } }` — per-stage tool containers |
| `pipeline-utility-steps` | `readJSON`, `readYaml`, `zip`, `findFiles` inside pipelines |
| `credentials-binding` | `withCredentials {}` to inject secrets without leaking them |
| `timestamper` | timestamps on every console line |
| `ansicolor` | colored console output |
| `ws-cleanup` | `cleanWs()` to wipe the workspace between runs |
| `build-timeout` | a global guard so a hung build doesn't run forever |
| `warnings-ng` | aggregates lint/compiler/scanner output with trend graphs |
| `htmlpublisher` | pins an HTML report (coverage, etc.) to the job page |
| `dark-theme` | Manage Jenkins → Appearance |
| `blueocean` | the modern visual pipeline view (heavy — the one to drop if builds are slow) |

## Add your own job

Copy any `jobs/<name>/config.xml`, change the `<description>` and the `<script>`,
rebuild. Or write the pipeline in the Jenkins UI first (New Item → Pipeline),
get it working, then **Configure → the config.xml is what you'd copy back here**.
