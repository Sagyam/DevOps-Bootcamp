# 🚀 DevOps & Platform Engineering Bootcamp

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Linux-Kernel%20%7C%20CLI%20%7C%20Systemd-FCC624?logo=linux&logoColor=black)](#week-1-linux-for-devops--system-internals--terminal-fluency)
[![Docker](https://img.shields.io/badge/Docker-Containers%20%7C%20Compose%20%7C%20Swarm-2496ED?logo=docker&logoColor=white)](#week-2-docker--containers--packaging-isolation--local-orchestration)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K8s%20%7C%20Helm%20%7C%20K9s-326CE5?logo=kubernetes&logoColor=white)](#week-4-container-orchestration-kubernetes--cluster-architecture--operations)
[![Terraform](https://img.shields.io/badge/Terraform-IaaC%20%7C%20AWS%20%7C%20Ansible-7B42BC?logo=terraform&logoColor=white)](#week-7-infrastructure-as-code-terraform--declarative-cloud--configuration-automation)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD%20%7C%20Flagger-EF7B4D?logo=argo&logoColor=white)](#week-8-gitops--progressive-delivery--argo-cd--flagger-on-kubernetes)
[![Observability](https://img.shields.io/badge/Observability-Prometheus%20%7C%20Grafana%20%7C%20Loki%20%7C%20Jaeger-F46800?logo=grafana&logoColor=white)](#week-6-observability--the-three-pillars-of-observability)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20%7C%20Jenkins-2088FF?logo=githubactions&logoColor=white)](#week-3-cicd-pipelines--automated-testing-security--continuous-delivery)

A comprehensive, production-grade, 9-week hands-on DevOps & Platform Engineering curriculum. Designed from the ground up to take practitioners from fundamental Linux systems administration to advanced progressive delivery, infrastructure as code, cloud architectures, full-stack observability, and production disaster recovery audits.

---

## 🧭 Core Philosophy & Pedagogy

1. **Apply, Observe, Break, and Fix:**
   Every module is built around hands-on interaction. Instead of theoretical hello-worlds, you interact with live systems, analyze failure modes, diagnose breaking changes in real time, and implement production-ready fixes.
2. **K9s as the Cockpit, kubectl as the Mirror:**
   Interactive terminal UIs (like K9s, Lazydocker, and Lazygit) allow you to visualize cluster and container state immediately, while mirroring every action with CLI commands for automation scripts and headless pipelines.
3. **Continuity & Real-World Stacks:**
   Applications like **ShortLink** (multi-tier microservices with Go, Python, Node, Redis, and Postgres) and **The Chiya Shop** (observable microservice) travel across modules—from containerization in Docker, to orchestration in Kubernetes, to continuous delivery with GitHub Actions and GitOps.
4. **Nightmare vs. Pristine Reference Architectures:**
   Learn not only what good looks like, but how real-world legacy codebases fail. Audit 80+ planted defects and architectural anti-patterns in the Capstone before delivering hardened, observable, and resilient infrastructure.

---

## 🗺️ 9-Week Curriculum Roadmap

```
DevOps Bootcamp
├── 🛠️  Onboarding        ── Automated Workstation Setup & DevOps Landscape
├── 🐧  Week 1: Linux     ── System Internals, Text Processing, Vim, Systemd & Cron
├── 🐳  Week 2: Docker    ── Containers, Multi-Stage Builds, Networks, Volumes & Compose
├── 🔄  Week 3: CI/CD     ── GitHub Actions, Secret Management, Runners & Jenkins
├── ☸️   Week 4: K8s       ── Pods, Deployments, Services, Storage, Helm, Ingress & K9s
├── ☁️   Week 5: AWS       ── IAM, VPC Networking, EC2, S3, RDS & Cloud Architecture
├── 🔭  Week 6: Observe   ── Logs (Loki), Metrics (Prometheus), Traces (OpenTelemetry/Jaeger)
├── 🏗️   Week 7: IaaC      ── Terraform Provider Mastery, State, Minikube & AWS + Ansible
├── ⚡  Week 8: GitOps    ── Argo CD & Flagger Progressive Canary Delivery on EKS
└── 🏆  Week 9: Capstone  ── The Tiffin Audit Lab: 83 Defects, Security, DR Drills & SRE
```

---

## 📚 Module-by-Module Breakdown

### [Onboarding](./Onboarding/) — *DevOps Landscape & Workstation Setup*
- **DevOps Culture & Tooling Landscape:** Overview of modern platform engineering, CI/CD cycles, feedback loops, and SRE principles.
- **Automated Workstation Setup:** Comprehensive bootstrap script ([`bootcamp-setup.sh`](./Onboarding/bootcamp-setup.sh)) supporting Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro, and openSUSE.
- **Toolchain:** Docker, Minikube, kubectl, K9s, Helm, Terraform, Ansible, AWS CLI, Lazydocker, Lazygit, bat, eza, btop, jq, and yq.
- **Slides:** [`DevOps_Day1_Landscape.pdf`](./Onboarding/DevOps_Day1_Landscape.pdf)

---

### [Week 1: Linux for DevOps](./Week-1%20Linux%20for%20DevOps/) — *System Internals & Terminal Fluency*
- **Filesystem Hierarchy & Navigation:** Deep dive into `/etc`, `/var`, `/proc`, `/sys`, permissions (`chmod`, `chown`, octal & symbolic modes, SUID/SGID).
- **Text Processing & Log Analysis:** Practical drills on [`text-processing/`](./Week-1%20Linux%20for%20DevOps/text-processing/) using `grep`, `awk`, `sed`, `cut`, `sort`, `uniq`, and `jq` to parse access logs, JSON payloads, and service configurations.
- **Vim Mastery:** Navigation, modal editing, macro execution, and configuration challenges ([`vim/`](./Week-1%20Linux%20for%20DevOps/vim/)).
- **Service Management & Automation:** `systemd` units, `journalctl` debugging, and cron scheduling workflows.
- **Interactive Simulations:** [`orbit-linux/`](./Week-1%20Linux%20for%20DevOps/orbit-linux/) live terminal challenges.
- **Cheatsheet & Slides:** [`Linux Cheatsheet.md`](./Week-1%20Linux%20for%20DevOps/Linux%20Cheatsheet.md) & [`Linux_for_DevOps.pdf`](./Week-1%20Linux%20for%20DevOps/Linux_for_DevOps.pdf).

---

### [Week 2: Docker & Containers](./Week-2%20Docker/) — *Packaging, Isolation & Local Orchestration*
- **10-Part Modular Lessons ([`lessons/`](./Week-2%20Docker/lessons/)):**
  1. CLI commands and container lifecycle
  2. Dockerfile fundamentals & caching mechanics
  3. Advanced instructions (`ENTRYPOINT` vs `CMD`, `COPY` vs `ADD`, `ARG` vs `ENV`)
  4. Best practices (multi-stage builds, non-root users, minimal base images)
  5. Container networking (bridge, host, overlay, internal DNS resolution)
  6. Persistent storage (named volumes, bind mounts, permissions)
  7. Registry workflows (tagging, push/pull, authentication)
  8. Multi-container orchestration with Docker Compose
  9. Containerized CI/CD pipelines
  10. Clustering and service replication with Docker Swarm
- **Real-World Application ([`shortlink/`](./Week-2%20Docker/shortlink/)):** A multi-tier URL shortener service featuring an API backend, Web frontend, Redis cache, PostgreSQL storage, asynchronous click analytics worker, health checks, and Swarm stack deployments.
- **Slides:** [`Docker_and_Containers.pdf`](./Week-2%20Docker/Docker_and_Containers.pdf).

---

### [Week 3: CI/CD Pipelines](./Week-3%20CI%20and%20CD/) — *Automated Testing, Security & Continuous Delivery*
- **Incremental GitHub Actions Curriculum ([`00-week-overview.md`](./Week-3%20CI%20and%20CD/00-week-overview.md)):**
  - **Day 1:** Workflow anatomy, event triggers, runners, steps, and jobs.
  - **Day 2:** Node.js CI (caching dependencies, linting, matrix testing).
  - **Day 3:** Containerized CI (building and publishing multi-arch Docker images to GHCR).
  - **Day 4:** Integration testing with database service containers (PostgreSQL / Redis).
  - **Day 5:** Security hardening, Action SHA-pinning, environments, approvals, and OIDC tokens.
  - **Day 6:** CD workflows, automated deployment strategies, and rollback automation.
- **Self-Hosted Runners:** Setup, registration, ephemeral runners, and security hardening ([`self-hosted-runners/`](./Week-3%20CI%20and%20CD/self-hosted-runners/)).
- **Jenkins Masterclass:** Declarative and Scripted Jenkinsfiles, pipeline agents, multibranch pipelines, and Dockerized master/agent clusters ([`jenkins-playground/`](./Week-3%20CI%20and%20CD/jenkins-playground/)).
- **Slides:** [`CICD_with_GitHub_Actions.pdf`](./Week-3%20CI%20and%20CD/CICD_with_GitHub_Actions.pdf).

---

### [Week 4: Container Orchestration (Kubernetes)](./Week-4%20Container%20Orchestration/) — *Cluster Architecture & Operations*
- **10-Day Hands-on Blueprint ([`kubernetes-lab-blueprint.md`](./Week-4%20Container%20Orchestration/kubernetes-lab-blueprint.md)):**
  - **Day 1:** Control plane architecture, Pod lifecycle, and manifest anatomy.
  - **Day 2:** Deployments, ReplicaSets, zero-downtime rolling updates, and rollbacks.
  - **Day 3:** Networking, ClusterIP, NodePort, LoadBalancer, and CoreDNS service discovery.
  - **Day 4:** Configuration management with ConfigMaps and Secrets.
  - **Day 5:** Storage orchestration (StorageClasses, PersistentVolumes, PersistentVolumeClaims, PostgreSQL stateful deployments).
  - **Day 6:** Health probes (Liveness, Readiness, Startup), resource requests/limits, and QoS tiers.
  - **Day 7:** Helm package management, chart creation, templating, and release management.
  - **Day 8:** NGINX Ingress Controller, routing rules, and TLS termination.
  - **Day 9:** Scheduling primitives (NodeSelectors, Node Affinity, Taints, Tolerations, Pod Anti-Affinity).
  - **Day 10:** Production extensions (Horizontal Pod Autoscalers, RBAC Roles & RoleBindings, and ShortLink cluster capstone).
- **Slides:** [`Kubernetes-Core-Concepts.pdf`](./Week-4%20Container%20Orchestration/Kubernetes-Core-Concepts.pdf).

---

### [Week 5: Cloud Computing (AWS)](./Week-5%20Cloud%20Computing/) — *Cloud Infrastructure & Architecture*
- **Identity & Access Management (IAM):** Users, Groups, Roles, Policies, Principle of Least Privilege, and MFA enforcement.
- **Virtual Private Cloud (VPC):** Custom VPC design, public/private subnets, Internet Gateways, NAT Gateways, Route Tables, Security Groups, and Network ACLs.
- **Compute & Elasticity:** EC2 instance families, Launch Templates, Auto Scaling Groups (ASG), and Application Load Balancers (ALB).
- **Storage & Databases:** S3 storage classes and lifecycle rules, Elastic Block Store (EBS), and Amazon RDS (Multi-AZ, read replicas, automated backups).
- **Monitoring & Audit:** CloudWatch metrics, alarms, and CloudTrail auditing.
- **Slides:** [`Cloud-Computing-AWS.pdf`](./Week-5%20Cloud%20Computing/Cloud-Computing-AWS.pdf).

---

### [Week 6: Observability](./Week-6%20Observability/) — *The Three Pillars of Observability*
- **The Chiya Shop Lab ([`README.md`](./Week-6%20Observability/README.md)):** An end-to-end telemetry lab using a tea shop microservice to explore real-world system behavior:
  - **Day 1 — Logs:** Centralized log aggregation with Grafana Loki, Alloy / Promtail collectors, and LogQL queries for real-time error tracing.
  - **Day 2 — Metrics:** Prometheus scraping, metric types (Counters, Gauges, Histograms), PromQL alerting rules, NGINX exporters, and Grafana dashboard design.
  - **Day 3 — Distributed Tracing:** Instrumenting applications with OpenTelemetry (OTel), Jaeger collector/UI, context propagation, and analyzing service latency bottlenecks.
- **Slides:** [`Observability-Logs-Metrics-Traces.pdf`](./Week-6%20Observability/Observability-Logs-Metrics-Traces.pdf).

---

### [Week 7: Infrastructure as Code (Terraform)](./Week-7%20IaaC/) — *Declarative Cloud & Configuration Automation*
- **Universal Reconciliation (`init` → `plan` → `apply` → `destroy`):**
  - **Lab 1 — Local Files & Fundamentals:** Terraform state engine, drift detection, variables, outputs, `templatefile`, and `for_each` meta-arguments ([`lab-01-local-files/`](./Week-7%20IaaC/lab-01-local-files/)).
  - **Lab 2 — Kubernetes Provider:** Managing Minikube / Kubernetes API resources declaratively using Terraform state reconciliation ([`lab-02-minikube/`](./Week-7%20IaaC/lab-02-minikube/)).
  - **Lab 3 — AWS + Ansible Hybrid Automation:** Provisioning VPC, Subnets, Internet Gateways, and EC2 instances via Terraform, feeding outputs dynamically into Ansible playbooks for automated server configuration ([`lab-03-terraform-ansible-ec2/`](./Week-7%20IaaC/lab-03-terraform-ansible-ec2/)).
- **Slides:** [`Infrastructure-as-Code-Terraform.pdf`](./Week-7%20IaaC/Infrastructure-as-Code-Terraform.pdf).

---

### [Week 8: GitOps & Progressive Delivery](./Week-8%20GitOps/) — *Argo CD & Flagger on Kubernetes*
- **Declarative GitOps Engine:** Argo CD installation, Application CRDs, App-of-Apps pattern, automated synchronization, self-healing, and drift correction ([`LAB.md`](./Week-8%20GitOps/LAB.md)).
- **Progressive Canary Deployments:** Flagger controller integration with NGINX Ingress and Prometheus metrics for automated Canary releases, traffic shifting, metric analysis, and instant automated rollbacks on error thresholds.
- **Deployment Strategies:** Deep dive into Recreate, Rolling Update, Blue-Green, Canary, and A/B Testing ([`strategies/README.md`](./Week-8%20GitOps/strategies/README.md)).
- **Guides:** [`INSTRUCTOR.md`](./Week-8%20GitOps/docs/INSTRUCTOR.md) & [`TROUBLESHOOTING.md`](./Week-8%20GitOps/docs/TROUBLESHOOTING.md).

---

### [Week 9: Capstone Project](./Week-9%20Capstone%20Project/) — *The Tiffin Audit Lab & SRE Gauntlet*
- **Real-World Platform Engineering Audit:** Compare an anti-pattern legacy codebase against a production-grade reference architecture ([`README.md`](./Week-9%20Capstone%20Project/README.md)):
  - **`tiffin-nightmare/`**: Legacy production deployment with **83 planted critical defects** (hardcoded secrets, SQL injection, CORS misconfigurations, root containers, missing volume persistence, deployment race conditions, missing health probes, unhandled signals, and 4 independent guarantees of catastrophic data loss).
  - **`tiffin-pristine/`**: Production-grade reference implementation featuring multi-stage distroless containers, non-root users, Zod schema validation, Pino structured logging with PII redaction, WAL-G automated database backups, Prometheus instrumentation, and full CI/CD automation.
- **Disaster Recovery Drills:** Live simulation of database drop and point-in-time recovery (PITR) ([`RUNBOOK-dr-drill.md`](./Week-9%20Capstone%20Project/tiffin-pristine/docs/RUNBOOK-dr-drill.md)).
- **Audit Matrix:** Detailed 83-defect remediation ledger ([`IMPROVEMENTS.md`](./Week-9%20Capstone%20Project/IMPROVEMENTS.md)).

---

## ⚡ Quickstart & Workstation Setup

### 1. Automated Setup Script
Run the workstation bootstrap script to install the entire bootcamp toolchain automatically:

```bash
# Clone the repository
git clone https://github.com/Sagyam/DevOps-Bootcamp.git
cd DevOps-Bootcamp

# Make the setup script executable and run
chmod +x Onboarding/bootcamp-setup.sh
./Onboarding/bootcamp-setup.sh
```

#### Script Options:
```bash
./Onboarding/bootcamp-setup.sh --list              # List all available tools
./Onboarding/bootcamp-setup.sh --only docker,k9s   # Install only specific tools
./Onboarding/bootcamp-setup.sh --skip vscode       # Skip GUI tools
./Onboarding/bootcamp-setup.sh --force terraform   # Reinstall or upgrade a tool
```

### 2. Manual Prerequisites Check
If setting up manually, verify your workstation has:
- **OS:** Linux (Ubuntu 22.04+, Debian 12+, Fedora 39+, Arch) or macOS with Docker Desktop / Colima / OrbStack.
- **Hardware:** Minimum 4 CPU cores, 8 GB RAM (16 GB recommended), 30 GB free disk space.
- **Core CLI Tools:** `git`, `docker` (with Compose v2), `kubectl`, `minikube`, `helm`, `k9s`, `terraform` (>= 1.5), `aws-cli` (v2), `jq`, `yq`, and `curl`.

---

## 🧰 Technology & Tooling Matrix

| Category | Primary Technologies & Tools |
|---|---|
| **Operating Systems & CLI** | Linux (Ubuntu, Debian, Alpine), Bash, Systemd, Vim, Awk, Sed, Jq, Yq, Btop |
| **Containers & Orchestration** | Docker, Docker Compose, Docker Swarm, Kubernetes, Minikube, Helm, K9s |
| **CI / CD Automation** | GitHub Actions, Self-Hosted Runners, Jenkins, Dockerized Build Pipelines |
| **Infrastructure as Code** | Terraform, Ansible, AWS Provider, Kubernetes Provider, Local Provider |
| **Cloud Computing** | AWS (VPC, IAM, EC2, S3, RDS, CloudWatch, ALB, ASG, EKS) |
| **GitOps & Delivery** | Argo CD, Flagger, NGINX Ingress Controller, Canary / Blue-Green Rollouts |
| **Observability & SRE** | Prometheus, Grafana, Grafana Loki, Alloy / Promtail, OpenTelemetry, Jaeger |
| **Security & Quality** | Action SHA Pinning, OIDC Tokens, Non-root containers, Zod validation, Pino PII redaction |

---

## 📖 Master Course Materials

- 📘 **Master Course PDF:** [`DevOps.pdf`](./DevOps.pdf) — Comprehensive companion slide book.
- 📑 **Module Presentations:**
  - [Onboarding Landscape](./Onboarding/DevOps_Day1_Landscape.pdf)
  - [Week 1: Linux for DevOps](./Week-1%20Linux%20for%20DevOps/Linux_for_DevOps.pdf)
  - [Week 2: Docker & Containers](./Week-2%20Docker/Docker_and_Containers.pdf)
  - [Week 3: CI/CD with GitHub Actions](./Week-3%20CI%20and%20CD/CICD_with_GitHub_Actions.pdf)
  - [Week 4: Kubernetes Core Concepts](./Week-4%20Container%20Orchestration/Kubernetes-Core-Concepts.pdf)
  - [Week 5: AWS Cloud Computing](./Week-5%20Cloud%20Computing/Cloud-Computing-AWS.pdf)
  - [Week 6: Observability (Logs, Metrics, Traces)](./Week-6%20Observability/Observability-Logs-Metrics-Traces.pdf)
  - [Week 7: Infrastructure as Code (Terraform)](./Week-7%20IaaC/Infrastructure-as-Code-Terraform.pdf)

---

## 🤝 Contributing

Contributions, feedback, and lab enhancements are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/NewLabExercise`)
3. Commit your Changes (`git commit -m 'Add new lab exercise'`)
4. Push to the Branch (`git push origin feature/NewLabExercise`)
5. Open a Pull Request

---

## 📄 License

Distributed under the **GNU General Public License v3.0**. See [`LICENSE`](./LICENSE) for full details.
