# Audit markers

Every planted defect in this repository is tagged with a marker of the form
`AUDIT-nn` (nn = 01 to 83).

**The marker tells you where to look.** To see why each item is problematic and
how it is properly implemented, consult `IMPROVEMENTS.md` in the root directory.

Find them all:

```bash
grep -rn "AUDIT-" . --include="*" | sort
```

## Coverage check

Below is the distribution of planted markers across the repository:

| File | Markers |
|---|---|
| `.gitignore` | 1 |
| `.env` | 1 |
| `src/index.js` | 11 |
| `src/db.js` | 3 |
| `test/smoke.test.js` | 1 |
| `Dockerfile` | 8 |
| `docker-compose.yml` | 8 |
| `.github/workflows/ci.yml` | 8 |
| `.github/workflows/deploy.yml` | 6 |
| `k8s/deployment.yaml` | 10 |
| `k8s/service.yaml` | 2 |
| `k8s/postgres-pod.yaml` | 4 |
| `k8s/secret.yaml` | 2 |
| `terraform/main.tf` | 15 |
| `terraform/NOTES.txt` | 1 |
| `docs/runbook.md` | 2 |
| **Total** | **83** |

## Findings with no marker

Some defects cannot be marked with comments because the defect is that **critical tooling or configuration is missing**.
For example:
- `package.json` has no test/lint scripts or lockfile
- No `.dockerignore` (build context sends `.git` and secrets)
- No linter (`eslint`) or code formatter (`prettier`)
- No `.editorconfig`
- No database migrations
- No Kubernetes `NetworkPolicy`, `PodDisruptionBudget`, or `HPA`
- No automated backup jobs
- No PR templates or security scanners (`gitleaks`, `trivy`)

Noticing these architectural absences is just as vital as finding marked code bugs.
Compare this repository with `tiffin-pristine/` and read `IMPROVEMENTS.md` for full context on every fix.
