#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Day-0 bootstrap. Run this ONCE, by hand, after `terraform apply` finishes.
#
# Why by hand? This is the chicken-and-egg of GitOps: something has to install
# the thing that installs everything else. Terraform made the cluster; these
# three Helm releases make the cluster able to manage itself. From here on,
# nothing is installed by hand again -- it all goes through Git.
# ---------------------------------------------------------------------------
set -euo pipefail

echo "==> Sanity check: can we reach the cluster?"
kubectl get nodes

echo "==> Adding Helm repos"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add flagger https://flagger.app
helm repo update

# ---------------------------------------------------------------------------
# 1. ingress-nginx -- the data plane. Install first so its load balancer has
#    the longest head start (AWS takes 2-4 minutes to make an NLB healthy).
# ---------------------------------------------------------------------------
echo "==> Installing ingress-nginx"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --values bootstrap/ingress-nginx-values.yaml \
  --wait --timeout 10m

# ---------------------------------------------------------------------------
# 2. Argo CD -- the control loop for application state.
# ---------------------------------------------------------------------------
echo "==> Installing Argo CD"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --values bootstrap/argocd-values.yaml \
  --wait --timeout 10m

# ---------------------------------------------------------------------------
# 3. Flagger -- the control loop for progressive delivery.
#    CRDs are applied explicitly. Helm will not upgrade CRDs that already
#    exist, so making this a separate, visible step saves you a confusing
#    failure six months from now.
# ---------------------------------------------------------------------------
echo "==> Installing Flagger CRDs"
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml

echo "==> Installing Flagger"
helm upgrade --install flagger flagger/flagger \
  --namespace ingress-nginx \
  --values bootstrap/flagger-values.yaml \
  --wait --timeout 5m

echo "==> Installing the Flagger load tester into the app namespace"
kubectl create namespace chiya --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install flagger-loadtester flagger/loadtester \
  --namespace chiya \
  --values bootstrap/loadtester-values.yaml \
  --wait --timeout 5m

echo
echo "==> Done. Now run: ./scripts/urls.sh"
