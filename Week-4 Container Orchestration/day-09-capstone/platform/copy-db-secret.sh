#!/usr/bin/env bash
# CloudNativePG generates the Secret 'chiya-db-app' in the chiya-data namespace.
# The APIs run in chiya-app. Secrets do NOT cross namespaces -- that is the
# entire security value of a namespace.
#
# In production you would solve this with External Secrets Operator, Reflector,
# or kubernetes-replicator. Today we copy it by hand so you can see the seam.
set -euo pipefail

FROM_NS="${FROM_NS:-chiya-data}"
TO_NS="${TO_NS:-chiya-app}"
NAME="${NAME:-chiya-db-app}"

echo "waiting for $NAME in $FROM_NS ..."
for _ in $(seq 1 60); do
  kubectl -n "$FROM_NS" get secret "$NAME" >/dev/null 2>&1 && break
  sleep 3
done

kubectl -n "$FROM_NS" get secret "$NAME" -o json \
  | python3 -c '
import json,sys
s = json.load(sys.stdin)
s["metadata"] = {"name": s["metadata"]["name"]}
print(json.dumps(s))
' \
  | kubectl -n "$TO_NS" apply -f -

echo "copied $NAME -> $TO_NS"
kubectl -n "$TO_NS" get secret "$NAME"
