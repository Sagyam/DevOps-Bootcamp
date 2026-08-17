# Runbook: Database loss and recovery drill

**Owner:** platform team · **Last drill:** _record the date every quarter_

A runbook is written for someone at 2am who did not build the system. It has
no prose you have to think about. Every step is a command or a decision.

---

## 1. Targets

| Term                               | Meaning here               | Target                               |
| ---------------------------------- | -------------------------- | ------------------------------------ |
| **RPO** — Recovery Point Objective | How much data may we lose? | 24 h (nightly dump); 5 min with PITR |
| **RTO** — Recovery Time Objective  | How long may we be down?   | 60 min                               |

If a drill misses these numbers, the drill did not fail. The targets or the
architecture did. Record the real number and decide which one to change.

---

## 2. Triage: what actually broke?

Run these in order. Stop at the first that answers the question.

```bash
kubectl -n tiffin get pods                      # are the pods there?
kubectl -n tiffin logs deploy/tiffin --tail=50  # what are they saying?
kubectl -n tiffin get events --sort-by=.lastTimestamp | tail -20
aws rds describe-db-instances --db-instance-identifier tiffin-prod \
  --query 'DBInstances[0].DBInstanceStatus'     # is the database alive?
```

| Symptom                       | Likely cause                                   | Go to |
| ----------------------------- | ---------------------------------------------- | ----- |
| Pods `Running`, `/readyz` 503 | DB unreachable, credentials, or pool exhausted | §3    |
| Pods `CrashLoopBackOff`       | Bad config or bad image                        | §4    |
| RDS status not `available`    | Instance failure                               | §5    |
| Data present but wrong        | Bad migration or bad deploy                    | §6    |
| RDS instance gone entirely    | Deletion                                       | §7    |

---

## 3. Database reachable but unhealthy

```bash
kubectl -n tiffin exec -it deploy/tiffin -- \
  node -e "import('./src/db.js').then(m=>m.checkHealth()).then(console.log)"

# Connection count against max_connections
psql -h $PGHOST -U tiffin -c \
  "SELECT count(*), (SELECT setting FROM pg_settings WHERE name='max_connections') FROM pg_stat_activity;"

# Long-running queries holding locks
psql -h $PGHOST -U tiffin -c \
  "SELECT pid, now()-query_start AS age, left(query,60) FROM pg_stat_activity
   WHERE state='active' AND now()-query_start > interval '30 seconds' ORDER BY age DESC;"
```

Kill one blocking query: `SELECT pg_terminate_backend(<pid>);`

---

## 4. CrashLoopBackOff

```bash
kubectl -n tiffin logs deploy/tiffin --previous   # logs from the dead container
kubectl -n tiffin describe pod -l app.kubernetes.io/name=tiffin | tail -30
```

`Invalid configuration` in the logs means `src/config.js` rejected the
environment. That is working as designed. Fix the ConfigMap or ExternalSecret.

**Roll back** rather than debug forward during an incident:

```bash
kubectl -n tiffin rollout undo deployment/tiffin
kubectl -n tiffin rollout status deployment/tiffin --timeout=120s
```

Under GitOps, revert the commit instead so Argo CD does not re-apply the bad
state thirty seconds later.

---

## 5. Point-in-time restore (data loss within retention)

PITR creates a **new** instance. It does not overwrite the old one.

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier tiffin-prod \
  --target-db-instance-identifier tiffin-prod-restored \
  --restore-time 2026-08-17T09:15:00Z \
  --db-subnet-group-name tiffin-prod \
  --vpc-security-group-ids sg-0123456789abcdef0 \
  --no-publicly-accessible

aws rds wait db-instance-available --db-instance-identifier tiffin-prod-restored
```

Then cut over by updating the secret, **not** by editing pod environments:

```bash
aws secretsmanager put-secret-value --secret-id /tiffin/prod/db \
  --secret-string "$(jq -c '.host="tiffin-prod-restored...rds.amazonaws.com"' <<< "$CURRENT")"
kubectl -n tiffin rollout restart deployment/tiffin
```

---

## 6. Restore from a logical backup

```bash
aws s3 ls s3://tiffin-backups-ap-south-1/postgres/2026/08/ | tail -5

# ALWAYS restore to a scratch database first and check the numbers.
S3_BUCKET=tiffin-backups-ap-south-1 ./scripts/restore.sh \
  --key postgres/2026/08/tiffin-20260817T181500Z.dump \
  --target tiffin_restore_test
```

Compare the row counts the script prints against what you expect. Only then
consider promoting the restore.

---

## 7. Total loss

1. `terraform apply` rebuilds the RDS instance, KMS key, and networking.
2. Restore the most recent snapshot or S3 dump into it (§5 or §6).
3. Argo CD re-syncs the workloads with no manual step.
4. Verify with the checklist in §8.

If Terraform state itself is lost, the S3 backend is versioned — restore the
previous object version before doing anything else. Never `terraform import`
under time pressure with a live outage; that is how second outages happen.

---

## 8. Verification checklist

```bash
curl -fsS https://tiffin.example.np/healthz
curl -fsS https://tiffin.example.np/readyz
curl -fsS https://tiffin.example.np/menu | jq '.items | length'
```

- [ ] `/readyz` returns 200 on every replica
- [ ] Row counts match the pre-incident dashboard within RPO
- [ ] Error-rate panel back under 2%
- [ ] Alerts resolved, not silenced
- [ ] `tiffin_backup_last_success_timestamp` still fresh

---

## 9. Hands-on disaster recovery drill (self-guided)

You can run this drill against a local Minikube cluster or staging environment to experience realistic failure scenarios and recovery workflows first-hand.

### Setup (Minikube):

```bash
minikube start --cpus=4 --memory=6g
kubectl apply -k k8s/overlays/dev
kubectl -n tiffin-dev rollout status deploy/tiffin
```

### Drill Scenarios:

#### Scenario 1: Pod restart (Availability & Zero Downtime)

- **Inject:** Kill the running application pod:
  ```bash
  kubectl -n tiffin-dev delete pod -l app.kubernetes.io/name=tiffin
  ```
- **Observe:** Kubernetes immediately schedules a replacement pod. The Service routes traffic to healthy replicas without dropped requests.

#### Scenario 2: Database credential corruption (Readiness vs. Liveness)

- **Inject:** Corrupt the database password in the secret:
  ```bash
  kubectl -n tiffin-dev patch secret tiffin-db -p '{"stringData":{"password":"wrong-password"}}'
  kubectl -n tiffin-dev rollout restart deploy/tiffin
  ```
- **Observe:** The pods start and stay running because `/healthz` (liveness) checks the process itself. However, `/readyz` (readiness) fails because it cannot reach Postgres. Kubernetes removes the pods from Service endpoints (returning 503 rather than crashing the pods in a loop).
- **Recover:** Fix the password and observe the pod return to `Ready` automatically:
  ```bash
  kubectl -n tiffin-dev patch secret tiffin-db -p '{"stringData":{"password":"dev-only-not-a-real-password"}}'
  kubectl -n tiffin-dev rollout restart deploy/tiffin
  ```

#### Scenario 3: Backend database dependency loss

- **Inject:** Scale down the Postgres database:
  ```bash
  kubectl -n tiffin-dev scale statefulset/postgres --replicas=0
  ```
- **Observe:** Application pods remain alive (`/healthz` returns 200) but unready (`/readyz` returns 503).
- **Recover:** Scale Postgres back up:
  ```bash
  kubectl -n tiffin-dev scale statefulset/postgres --replicas=1
  kubectl -n tiffin-dev rollout status statefulset/postgres
  ```

#### Scenario 4: Table drop & data restoration

- **Inject:** Simulate catastrophic data loss on Postgres:
  ```bash
  kubectl -n tiffin-dev exec -it postgres-0 -- psql -U tiffin -c "DROP TABLE orders CASCADE;"
  ```
- **Observe:** `GET /orders/1` or `POST /orders` fails.
- **Recover:** Re-apply migrations or restore from dump (§6):
  ```bash
  npm run migrate
  ```

### Key Lesson: Nightmare vs. Pristine in DR

- In `tiffin-nightmare`, Scenario 2 crashes all pods immediately because liveness and readiness use the same unvalidated endpoint `/health`.
- In `tiffin-nightmare`, Scenario 4 is permanently catastrophic because there are no volumes, no migrations, and zero automated backups.
- In `tiffin-pristine`, liveness/readiness separation isolates faults, StatefulSet PVCs persist data, and automated backups enable fast, verifiable RTO.
