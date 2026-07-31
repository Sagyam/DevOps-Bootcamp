#!/usr/bin/env bash
# Tear down everything this lab created, in dependency order.
set -uo pipefail

echo "--> Helm releases"
helm uninstall kube-prometheus-stack -n monitoring   2>/dev/null || true
helm uninstall cnpg                  -n cnpg-system  2>/dev/null || true
helm uninstall cert-manager          -n cert-manager 2>/dev/null || true

echo "--> Custom resources (delete CRs before CRDs, or finalizers will hang)"
kubectl delete chiyas --all -A --ignore-not-found
kubectl delete clusters.postgresql.cnpg.io --all -A --ignore-not-found

echo "--> Our CRD + controller"
kubectl delete crd chiyas.chiyashop.dev --ignore-not-found

echo "--> Namespaces"
for ns in jobs-lab chiya-dev chiya-prod chiya-system chiya-db monitoring cnpg-system cert-manager; do
  kubectl delete ns "$ns" --ignore-not-found --wait=false
done

echo
echo "Done. Nuclear option if something is stuck:  minikube delete --profile jobs-lab"
