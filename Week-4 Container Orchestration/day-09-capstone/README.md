# Chiya Shop -- Kubernetes capstone

A three-tier application that exists to make every Kubernetes concept you have
learned do something real, at the same time, in one cluster.

```
Browser
  |
  v
chiya-edge     Traefik            TLS, routing, compression, rate limiting
  |
  v
chiya-app      chiya-web          static site, Deployment + ConfigMap
               orders-api         Go, write path, anti-affinity
               kitchen-api        Node, worker + HPA target + RBAC demo
  |
  v
chiya-data     postgres cluster   3 pods, managed by the CloudNativePG OPERATOR
               valkey             StatefulSet we wrote by hand

cnpg-system    the operator itself
```

## Three stages

| Stage | You do | The registry ends up with |
|---|---|---|
| 1 | Push `apps/` -> CI builds three images | `ghcr.io/<you>/{chiya-web,orders-api,kitchen-api}` |
| 2 | Push `charts/` -> CI packages and pushes charts | `ghcr.io/<you>/charts/*` |
| 3 | `helm install` from that registry | A running six-component system |

Then you change two values files and the whole topology rearranges itself.

## Start here

Read **STUDENT-GUIDE.md**. Do not skip the pre-flight section.

## Layout

```
apps/                three microservices, three languages
charts/              five Helm charts (three apps, one data layer, one umbrella)
platform/            cluster infrastructure: scripts, Traefik, CRD, quotas
values-dev.yaml      the small topology
values-prod.yaml     the real one
.github/workflows/   the two pipelines
```

Instructor notes and the answer key live in **INSTRUCTOR-NOTES.md**.
