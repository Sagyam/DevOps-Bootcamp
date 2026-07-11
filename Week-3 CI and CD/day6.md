# Day 6 — Capstone: one pipeline, all the way to AWS

**Project:** `day6-capstone/` · **Deploy target:** Amazon ECS Express Mode

## Session plan (for the instructor)

| Block | Focus | ~Time |
|-------|-------|-------|
| 1 | Tour the stateless app + Dockerfile; why stateless matters | 20 min |
| 2 | The keyless-deploy story (OIDC) — the day's big idea | 25 min |
| 3 | Read the pipeline; first run creates the Express service (live) | 45 min |
| 4 | Hit the URL, watch autoscaling/hostnames; rubric + teardown | 30 min |

Objectives: students assemble the full pipeline — quality gate, image build/push
to ECR, and a gated deploy to a real AWS service — and can explain why OIDC
replaces stored cloud credentials.

---

## The problem this fixes

Two days ago the deploy was SSH into a box with a private key in a secret. Today
there are **no long-lived cloud credentials at all**. GitHub presents a
short-lived OIDC token; AWS trusts it (scoped to *this* repo) and hands back
temporary credentials. If the token leaks, it's already expired. That's the
lesson to hammer: the most secure secret is the one that doesn't exist.

## Block 2 — OIDC, concretely

Walk the trust chain on the board:
1. The workflow requests `id-token: write` and calls `configure-aws-credentials`.
2. GitHub mints a signed token whose `sub` says `repo:ORG/REPO:...`.
3. The IAM role's trust policy only accepts that exact `sub` and audience.
4. AWS returns 15-minute credentials. No `AWS_ACCESS_KEY_ID` anywhere.

Show `bootstrap/setup-aws.sh` — the trust policy is the whole security boundary.

## Block 3 — the pipeline

`quality` (lint + unit tests) gates everything. `deploy` (only after quality)
logs into ECR, builds the SHA-tagged image, pushes it, and calls the
`amazon-ecs-deploy-express-service` action. Emphasise: Express Mode is **not**
ECR-watch auto-deploy — the pipeline explicitly rolls the service, and ECS then
pulls the image. The **first** run *creates* the service (provisioning takes a
few minutes and builds an ALB + Fargate service + autoscaling); later runs
*update* it. Every action is SHA-pinned — Day 5's habit, carried forward.

## Block 4 — see it, then kill it

Open the URL from the run summary. Refresh `/` a few times: `servedBy` changes as
the load balancer spreads requests across tasks. Then be disciplined about
**teardown** — a Fargate task + ALB bills around the clock. Deleting the service
at module end is part of the exercise, not an afterthought.

## Recap

CI's job ends at a trustworthy, SHA-tagged image in ECR. Deployment is a separate
call, authenticated without a single stored key, gated behind an environment.
Stateless design is what makes that deploy safe to repeat. That's a complete,
modern CD pipeline — and nothing in it can strand you the way an SSH key did.
