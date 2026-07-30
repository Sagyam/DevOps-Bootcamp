#!/usr/bin/env bash
# Drive kitchen-api hard enough for the HPA to notice.
# Open 'kubectl get hpa,pods -n chiya-app -w' or k9s in another pane first.
set -euo pipefail

PROFILE="${PROFILE:-chiya}"
BASE="${BASE:-https://$(minikube -p "$PROFILE" ip):30443}"
DUR="${DUR:-90}"
CONC="${CONC:-40}"

URL="$BASE/api/kitchen/cook?ms=1500"
echo "hammering $URL for ${DUR}s with ${CONC} workers"

if command -v hey >/dev/null 2>&1; then
  hey -z "${DUR}s" -c "$CONC" -disable-keepalive "$URL"
  exit 0
fi

echo "(hey not installed -- falling back to a curl storm)"
END=$(( $(date +%s) + DUR ))
for _ in $(seq 1 "$CONC"); do
  (
    while [ "$(date +%s)" -lt "$END" ]; do
      curl -sk -o /dev/null "$URL" || true
    done
  ) &
done
wait
echo "done. watch the HPA scale back down over the next minute or two."
