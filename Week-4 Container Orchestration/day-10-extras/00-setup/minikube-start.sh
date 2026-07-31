#!/usr/bin/env bash
# Day setup: one cluster, enough headroom for an operator or two.
set -euo pipefail

PROFILE="${PROFILE:-jobs-lab}"

minikube start \
  --profile "$PROFILE" \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --kubernetes-version=v1.31.0 \
  --driver=docker

minikube --profile "$PROFILE" addons enable metrics-server

kubectl config use-context "$PROFILE"
kubectl get nodes -o wide
kubectl top nodes || echo "metrics-server still warming up, retry in ~60s"

echo
echo "Cluster '$PROFILE' is ready. Launch k9s in a second terminal and leave it running."
