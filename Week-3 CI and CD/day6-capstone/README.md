# Day 6 — Capstone: ship a stateless service to AWS

The whole week in one pipeline: **quality gate → build & push to ECR → deploy to
ECS Express Mode**, authenticated with **no stored AWS keys** (GitHub OIDC).

The app is a deliberately tiny **stateless monolith** — no database, no
orchestration. Stateless is the point: it's why many identical copies can run
behind a load balancer and why redeploying is safe.

## What is ECS Express Mode?

One API call gives ECS a container image and two IAM roles, and it provisions a
whole stack for you: a Fargate service, an Application Load Balancer, autoscaling,
networking, and an HTTPS URL like `https://<service>.ecs.<region>.on.aws/`. It's
the successor to AWS App Runner (which is now closed to new customers). There's no
extra charge for Express Mode itself — you pay for the Fargate + ALB it runs.

**It is not "auto-pull on push."** Unlike App Runner, Express Mode doesn't watch
ECR. Your pipeline makes an explicit deploy call; ECS then pulls the image you
named. Push-triggered, pull-executed.

## One-time setup per AWS account

```bash
cd bootstrap
GITHUB_ORG=your-org GITHUB_REPO=your-repo AWS_REGION=us-east-1 ./setup-aws.sh
```

That script creates the GitHub OIDC provider, a keyless deploy role scoped to your
repo, the two roles Express Mode needs (`ecsTaskExecutionRole`,
`ecsInfrastructureRoleForExpressServices`), and an ECR repository. Then set the
four repo **Variables** it prints (`AWS_REGION`, `AWS_ACCOUNT_ID`,
`ECR_REPOSITORY`, `ECS_SERVICE`).

## Run it

Push any change under `day6-capstone/**`, or run the workflow manually. The
**first** run creates the Express Mode service (3–5 min to provision); later runs
roll it to the new image. The run summary prints the live URL.

Hit `/` (JSON greeting with the task hostname) and `/health` (used by the ALB).

## Cost warning (say this to students)

A running Fargate task **plus an ALB bills ~24/7** — a few dollars per account per
month while it's up. When the module ends, tear it down:

```bash
aws ecs delete-express-gateway-service --service-arn <arn>   # then remove the ECR repo + roles if unused
```

## Grading rubric

| Criterion | Done looks like |
| --- | --- |
| Scoping | Workflow triggers only on `day6-capstone/**` |
| Quality gate | `deploy` needs `quality`; a failing test blocks the deploy |
| Keyless auth | OIDC role assumed; no AWS keys in secrets anywhere |
| Image | SHA-tagged image in ECR, built from the Dockerfile |
| Deploy | Express Mode service reaches ACTIVE; URL serves the new version |
| Least privilege | `permissions:` scoped; `id-token: write` only where needed |
