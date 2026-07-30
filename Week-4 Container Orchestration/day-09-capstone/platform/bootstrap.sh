#!/usr/bin/env bash
# Chiya Shop capstone -- cluster bootstrap for minikube.
#
#   ./platform/bootstrap.sh
#   NODES=2 MEM=2200 ./platform/bootstrap.sh      # for an 8 GB laptop
#
# Everything here is platform infrastructure. It is NOT part of the app,
# and that separation is the point: an application team should never have
# to install an operator or a gateway.
set -euo pipefail

PROFILE="${PROFILE:-chiya}"
NODES="${NODES:-3}"
CPUS="${CPUS:-2}"
MEM="${MEM:-2600}"

say() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- 1. cluster
say "starting minikube profile '$PROFILE' with $NODES node(s)"
minikube start -p "$PROFILE" \
  --nodes "$NODES" \
  --cpus "$CPUS" \
  --memory "$MEM" \
  --driver=docker

kubectl config use-context "$PROFILE"

# ---------------------------------------------------------------- 2. topology
# minikube names extra nodes <profile>-m02, <profile>-m03, ...
# We build three logical tiers so taints, tolerations and affinity have
# something real to act on.
say "labelling and tainting nodes"
CP="$PROFILE"

case "$NODES" in
  1)
    kubectl label node "$CP" tier=app ingress-ready=true --overwrite
    cat <<'WARN'

!! SINGLE NODE MODE
!! There is no separate data node, so nothing is tainted and the data layer
!! must be told to live on the app node. In stage 3, install chiya-data with:
!!
!!   --set postgres.nodeSelector.tier=app --set valkey.nodeSelector.tier=app \
!!   --set postgres.instances=2
!!
!! The taint demo (4.2) will not work. Everything else will.

WARN
    ;;
  2)
    kubectl label node "$CP"          tier=app ingress-ready=true --overwrite
    kubectl label node "${CP}-m02"    tier=data --overwrite
    kubectl taint node "${CP}-m02"    tier=data:NoSchedule --overwrite
    ;;
  *)
    kubectl label node "$CP"          tier=app ingress-ready=true --overwrite
    kubectl label node "${CP}-m02"    tier=app --overwrite
    kubectl label node "${CP}-m03"    tier=data --overwrite
    kubectl taint node "${CP}-m03"    tier=data:NoSchedule --overwrite
    ;;
esac
kubectl get nodes -L tier -L ingress-ready

# ---------------------------------------------------------------- 3. addons
say "enabling addons (metrics-server is REQUIRED for the HPA)"
minikube -p "$PROFILE" addons enable metrics-server
minikube -p "$PROFILE" addons enable default-storageclass
minikube -p "$PROFILE" addons enable storage-provisioner

echo "waiting for metrics-server..."
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s || true

# ---------------------------------------------------------------- 4. namespaces
say "creating namespaces and a quota"
for ns in chiya-app chiya-data chiya-edge; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done
kubectl apply -f "$(dirname "$0")/quota.yaml"

# ---------------------------------------------------------------- 5. operator
say "installing the CloudNativePG operator"
helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
helm repo update cnpg >/dev/null
helm upgrade --install cnpg cnpg/cloudnative-pg \
  -n cnpg-system --create-namespace --wait --timeout 5m

echo
echo "the operator just taught the API server three new nouns:"
kubectl get crd | grep cnpg || true

# ---------------------------------------------------------------- 6. gateway
say "installing Traefik"
helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update traefik >/dev/null
helm upgrade --install traefik traefik/traefik \
  -n chiya-edge -f "$(dirname "$0")/traefik-values.yaml" --wait --timeout 5m

# ---------------------------------------------------------------- 7. TLS
say "creating a self-signed TLS secret in chiya-app"
if ! kubectl -n chiya-app get secret chiya-tls >/dev/null 2>&1; then
  TMP=$(mktemp -d)
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout "$TMP/tls.key" -out "$TMP/tls.crt" \
    -subj "/CN=chiya.local" \
    -addext "subjectAltName=DNS:chiya.local,DNS:localhost,IP:127.0.0.1" 2>/dev/null
  kubectl -n chiya-app create secret tls chiya-tls \
    --cert="$TMP/tls.crt" --key="$TMP/tls.key"
  rm -rf "$TMP"
fi

# ---------------------------------------------------------------- done
IP=$(minikube -p "$PROFILE" ip)
say "platform ready"
cat <<EOF

  cluster profile : $PROFILE
  minikube ip     : $IP

  Once you install the app in stage 3, reach it at:

      https://$IP:30443       (Linux / docker driver -- works directly)

  On macOS or Windows the docker-driver IP is not routable from the host.
  Use a tunnel instead, in its own terminal:

      minikube -p $PROFILE service traefik -n chiya-edge --url

  Next: ./platform/set-owner.sh <your-github-username>

EOF
