# Terraform, One Step at a Time

A three-part lab that builds Terraform intuition incrementally. Same workflow every time
(`init → plan → apply → destroy`) — only the **provider** changes:

| Lab | Provider | What Terraform manages | New ideas introduced |
|---|---|---|---|
| 01 | `local`, `random` | Files on your own laptop | init/plan/apply, state, drift, variables, `templatefile`, `for_each` |
| 02 | `kubernetes` | Your minikube cluster | Providers talk to *APIs*, declarative reconciliation, drift vs. a live system |
| 03 | `aws` + Ansible | Real EC2 + full networking | VPC/subnet/IGW/SG, outputs feeding Ansible, provision vs. configure split |

**The big idea:** Terraform doesn't "know about" servers or clouds. It knows about
*providers*, and providers know how to turn desired state into API calls. A file on disk,
a Deployment in Kubernetes, and an EC2 instance are all just resources. Once students see
the same four commands work against three wildly different backends, Terraform stops being
"an AWS tool" and becomes what it actually is: a universal reconciliation loop.

## Prerequisites

- Linux, Terraform >= 1.5 installed (`terraform version`)
- Lab 02: minikube + kubectl
- Lab 03: an AWS account with credentials configured (`aws configure`), Ansible >= 2.15

## Suggested pacing

- Lab 01: ~45 min (do the drift experiment — it's the whole point)
- Lab 02: ~45 min
- Lab 03: ~2 hours (Terraform ~45 min, Ansible ~60 min, verification ~15 min)

## Terraform ↔ Ansible: who does what?

| | Terraform | Ansible |
|---|---|---|
| Job | **Provision** — make infrastructure *exist* | **Configure** — make machines *correct* |
| Model | Declarative + state file | Declarative-ish + idempotent tasks, no state |
| Question it answers | "Is there a server?" | "Is nginx on that server set up right?" |
| Analogy | Buys the land and builds the chiya shop | Stocks the shelves and trains the staff |

Lab 03 makes the handoff literal: Terraform *writes the Ansible inventory file* as one of
its outputs. Point this out to students — it's Lab 01's `local_file` trick, reused in production.
