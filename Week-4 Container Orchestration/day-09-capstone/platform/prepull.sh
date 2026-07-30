#!/usr/bin/env bash
# Bandwidth is the thing that actually kills a Kubernetes lab day.
#
#   ./platform/prepull.sh pull     <- run this AT HOME the night before
#   ./platform/prepull.sh load     <- run this in class, pushes into minikube
set -euo pipefail

PROFILE="${PROFILE:-chiya}"

IMAGES=(
  "traefik:v3.3"
  "valkey/valkey:8-alpine"
  "nginx:1.27-alpine"
  "postgres:17-alpine"
)

MODE="${1:-pull}"

case "$MODE" in
  pull)
    for img in "${IMAGES[@]}"; do
      echo "==> docker pull $img"
      docker pull "$img"
    done
    echo
    echo "done. Do NOT run 'docker system prune' before class."
    echo "The operator and Postgres images are pulled by the operator itself;"
    echo "run './platform/bootstrap.sh' once at home too, then 'minikube stop'."
    ;;
  load)
    for img in "${IMAGES[@]}"; do
      echo "==> minikube image load $img"
      minikube -p "$PROFILE" image load "$img"
    done
    ;;
  *)
    echo "usage: $0 [pull|load]" >&2
    exit 1
    ;;
esac
