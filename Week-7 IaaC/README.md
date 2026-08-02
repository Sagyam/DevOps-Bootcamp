# Terraform on AWS & Kubernetes — 3-Hour Lab

A hands-on lab where you build real AWS infrastructure with Terraform, ending with a
Kubernetes cluster you provisioned yourself and an application deployed onto it.

Everything here works identically on **Windows, macOS and Linux**.

---

## What you will build

```
                      ┌──────────────────────────────────────────┐
                      │  S3: state bucket + data bucket          │  Lab 01
                      └──────────────────────────────────────────┘
                                        │
                      ┌──────────────────────────────────────────┐
                      │  IAM: role + policy + instance profile   │  Lab 02
                      └──────────────────────────────────────────┘
                            │                          │
          ┌─────────────────▼──────────┐   ┌───────────▼──────────────┐
          │  EC2 + EBS                 │   │  ECR repository          │  Labs 03–04
          │  nginx, extra volume       │   │  immutable tags          │
          └────────────────────────────┘   └───────────┬──────────────┘
                                                       │ nodes pull from here
                      ┌────────────────────────────────▼─────────────┐
                      │  EKS: control plane + managed node group     │  Lab 05
                      └────────────────────────────────┬─────────────┘
                                                       │
                      ┌────────────────────────────────▼─────────────┐
                      │  Kubernetes: ns, configmap, deploy, service  │  Lab 06
                      └──────────────────────────────────────────────┘
```

---

## Agenda

| # | Lab | Time | Core idea |
|---|---|---|---|
| 00 | [Setup](labs/00-setup.md) | 15 min | tooling, credentials, how to work |
| 01 | [S3 & remote state](labs/01-s3-and-state.md) | 25 min | state is the whole ballgame |
| 02 | [IAM](labs/02-iam.md) | 25 min | trust policy vs permission policy |
| 03 | [EC2 & EBS](labs/03-ec2-ebs.md) | 30 min | data sources, lifecycles, user_data |
| 04 | [ECR](labs/04-ecr.md) | 15 min | immutable tags, lifecycle policies |
| 05 | [EKS](labs/05-eks.md) | 45 min | a cluster is five resource types |
| 06 | [Kubernetes](labs/06-kubernetes.md) | 25 min | provider chicken-and-egg |
| 07 | [Teardown](labs/07-teardown.md) | 15 min | destroy order, orphan hunting |

Also here: [CHEATSHEET.md](CHEATSHEET.md) — commands, syntax and error decoder.

---

## Prerequisites

- An AWS account with admin (or near-admin) permissions
- Terraform **>= 1.9** installed
- AWS CLI v2 configured (`aws sts get-caller-identity` must succeed)
- `kubectl` installed
- Docker — **optional**, only for one bonus step

Region for everything: **`ap-south-1` (Mumbai)**.

---

## Cost

Roughly **$0.30–$0.80** for the session, if you destroy at the end.

| Resource | Approx. rate | 3 hours |
|---|---|---|
| EKS control plane | $0.10 / hr | ~$0.30 |
| 2 × t3.medium nodes | ~$0.045 / hr each | ~$0.27 |
| t3.micro instance | ~$0.011 / hr | ~$0.03 |
| EBS gp3, ~50 GiB total | ~$0.09 / GB-month | ~$0.02 |
| S3 + ECR | pennies | ~$0.00 |

*Rates are approximate and change — check the AWS pricing page for current figures.*

**The control plane bills whether or not you use it.** Lab 07 is mandatory. Set a budget
alert at $5 before you start.

---

## Repo layout

```
labs/                 the guides you read
code/                 working Terraform (the answer key)
  01-s3-state/  02-iam/  03-ec2-ebs/  04-ecr/  05-eks/  06-kubernetes/
scripts/              preflight + destroy helpers (bash and PowerShell)
CHEATSHEET.md
INSTRUCTOR-NOTES.md
```

Each `code/` folder is its own **root module**: its own `init`, its own state. That
separation is the lesson, not an accident.

---

## How to get the most out of today

The `code/` directories contain finished configuration. You will learn roughly three times
as much if you open an empty `main.tf` and type it yourself, opening the provided file only
when stuck. Reading HCL is easy; writing it is where it sticks.

**A note on `terraform destroy`:** it is not a failure state. Being able to destroy and
rebuild your entire environment on demand is the actual product Terraform sells you.
