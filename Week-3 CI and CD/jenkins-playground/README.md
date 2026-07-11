# Jenkins JCasC playground

A throwaway, fully-configured Jenkins you can boot with one command — no setup
wizard, no manual plugin clicking, no job creation by hand. It exists so you can
*show* Jenkins as a contrast to GitHub Actions in ~20 minutes without burning the
class on setup.

## Run it

```bash
docker compose up --build
```

Then open http://localhost:8080 and log in with **admin / admin**.

You'll land on a Jenkins that already has:
- the setup wizard skipped,
- an admin user and login-required authorization,
- **six ready-made pipeline jobs** to explore,

...all defined in files in this folder, not clicked together.

Click any job → **Build Now** to watch it run. Open **Configure** to see the
pipeline, or **Manage Jenkins → Configuration as Code** to see the live JCasC.

See **`JENKINS-PIPELINES.md`** for what each example teaches (parameters +
approval gates, parallel + matrix, retry/timeout/post, scripted Groovy, and a
Docker-agent example) and a rundown of the pre-installed quality-of-life plugins.

## What each file does

| File | Role |
| --- | --- |
| `docker-compose.yml` | Builds + runs the container, maps port 8080, passes admin creds |
| `Dockerfile` | Base LTS image + plugins + skip-wizard + bakes the seed job |
| `plugins.txt` | The plugins installed at build time |
| `casc/jenkins.yaml` | The whole server config as code (the star of the show) |
| `jobs/hello-ci/config.xml` | The seeded pipeline job |

## The teaching contrast (say this out loud)

| | GitHub Actions | Jenkins |
| --- | --- | --- |
| Who runs it | GitHub's managed infra | a controller **you** operate |
| Config | YAML workflow, event-driven | Groovy `Jenkinsfile` + plugins |
| Extensibility | Marketplace actions | ~1,800 plugins |
| This repo's point | — | *even "ready to go" is a Docker image you had to build* |

That last row is the honest lesson: the reason we don't do a hands-on Jenkins lab
is sitting in this `Dockerfile`. Getting Jenkins to "just work" for a class means
pre-baking plugins, config, and jobs. GitHub Actions had none of that ceremony.

## Optional: create the job from JCasC instead of config.xml

Open `casc/jenkins.yaml` and follow the `--- 8< ---` markers to uncomment the
Job DSL block. Restart (`docker compose up --build`) and you'll get a second job,
`hello-from-jcasc`, created by JCasC on boot. This shows "jobs as code."

## Notes

- **Credentials** are `admin/admin` — fine for a local throwaway, change them
  (in `docker-compose.yml`) for anything else.
- **No persistence** by default: every `docker compose up` is a clean slate.
  Uncomment the named volume in the compose file to keep jobs and history.
- **Building real Docker images inside this pipeline** would need the Docker
  socket mounted into the container, which has real security caveats — left out
  on purpose. The sample pipeline uses plain `sh` steps.
- **Tear down:** `docker compose down` (add `-v` if you enabled the volume).
