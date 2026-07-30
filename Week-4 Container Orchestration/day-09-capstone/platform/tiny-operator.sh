#!/usr/bin/env bash
# The world's least impressive operator, and it is a real one.
#
# An operator is exactly three things in a loop:
#   1. read desired state  (the custom resources)
#   2. read actual state   (what exists in the cluster)
#   3. make 2 look like 1
#
# Everything a production operator adds on top of this -- leader election,
# work queues, exponential backoff, status subresources, finalizers, webhooks --
# is engineering around those three lines, not a different idea.
set -euo pipefail

NS="${NS:-chiya-app}"
echo "reconciling ChiyaSpecials in namespace $NS. ctrl-c to stop."

while true; do
  # 1. desired state
  kubectl get chiyaspecials -n "$NS" -o json 2>/dev/null \
    | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for i in d.get("items", []):
    s = i.get("spec", {})
    print(i["metadata"]["name"], s.get("priceNpr",0), s.get("spiceLevel","?"), s.get("flavour",""), sep="\t")
' \
  | while IFS=$'\t' read -r name price spice flavour; do
      # 3. make actual state match
      kubectl create configmap "special-$name" -n "$NS" \
        --from-literal=flavour="$flavour" \
        --from-literal=priceNpr="$price" \
        --from-literal=spiceLevel="$spice" \
        --dry-run=client -o yaml \
      | kubectl apply -f - >/dev/null
      echo "  reconciled $name -> configmap/special-$name"
    done

  sleep 5
done
