#!/usr/bin/env bash
# Replace REPLACE_ME with your GitHub username/org everywhere it matters.
# OCI reference names must be lowercase, so we lowercase it for you --
# this is the single most common CI failure in this lab.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <github-username-or-org>" >&2
  exit 1
fi

OWNER=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
cd "$(dirname "$0")/.."

FILES=$(grep -rl 'REPLACE_ME' --include='*.yaml' --include='*.yml' --include='*.md' . || true)
if [ -z "$FILES" ]; then
  echo "nothing to replace -- already configured?"
  exit 0
fi

printf '%s\n' "$FILES" | while IFS= read -r f; do
  sed -i.bak "s|REPLACE_ME|$OWNER|g" "$f"
  rm -f "$f.bak"
  echo "  patched $f"
done

echo
echo "owner set to: $OWNER"
echo "commit and push -- that is stage 1."
