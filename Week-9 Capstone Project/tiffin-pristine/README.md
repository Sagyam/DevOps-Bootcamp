# Tiffin

Office lunch ordering service. This is the **reference implementation** —
the state the legacy `tiffin-nightmare` repository should have been in.

## Before the first run

This repo ships without `package-lock.json` (it is generated, and pinning it
here would go stale). Generate it once, then commit it — the lockfile is part
of the lesson:

```bash
npm install            # writes package-lock.json
npm run format:fix     # normalise formatting so `npm run format` passes
git add package-lock.json
```

After that, `npm ci` and the Dockerfile's test stage work as written.

## Quick start

```bash
cp .env.example .env        # then edit PGPASSWORD
docker compose up -d --build
npm ci
npm run migrate
npm test
curl -s localhost:3000/menu | jq
```

## Layout

| Path                      | What it holds                                                               |
| ------------------------- | --------------------------------------------------------------------------- |
| `src/`                    | Application. `config.js` validates env, `db.js` is the only SQL entry point |
| `test/unit`               | Fast, no dependencies                                                       |
| `test/integration`        | Real app, real Postgres                                                     |
| `db/migrations`           | Forward-only, numbered SQL                                                  |
| `k8s/base`                | Environment-agnostic manifests                                              |
| `k8s/overlays/{dev,prod}` | Minikube vs EKS differences, via Kustomize                                  |
| `terraform/`              | VPC, RDS, KMS, S3 backups. Remote state, no secrets                         |
| `observability/`          | Alert rules and Grafana dashboard                                           |
| `scripts/`                | `backup.sh`, `restore.sh`                                                   |
| `docs/`                   | Architecture and the DR runbook                                             |

## Commands

```bash
npm run lint         # ESLint, incl. security plugin
npm run format       # Prettier check
npm test             # unit + integration
npm run test:coverage
docker compose up    # local stack
kubectl kustomize k8s/overlays/dev | kubectl apply -f -
terraform -chdir=terraform plan -var-file=example.tfvars
```

## The four CI gates

1. **Quality** — ESLint, Prettier, hadolint, kubeconform
2. **Tests** — unit + integration against a real Postgres, coverage thresholds
3. **Security** — gitleaks, Trivy (deps, IaC, secrets), tflint
4. **Build** — multi-stage image, scanned again after build

`main` is protected. All four gates must pass. Production deploys are tag-only
and require an approval on the `production` environment.
