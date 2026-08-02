#!/usr/bin/env bash
# Verify the lab machine is ready. macOS / Linux / Git Bash on Windows.
set -u

ok=0; fail=0
check() {
  printf "%-24s" "$1"
  if eval "$2" >/dev/null 2>&1; then
    echo "OK   $(eval "$3" 2>/dev/null | head -1)"
    ok=$((ok+1))
  else
    echo "MISSING  -> $4"
    fail=$((fail+1))
  fi
}

echo "Terraform lab preflight"
echo "-----------------------"
check "terraform"  "command -v terraform"  "terraform version | head -1"   "install Terraform >= 1.9"
check "aws cli"    "command -v aws"        "aws --version"                 "install AWS CLI v2"
check "kubectl"    "command -v kubectl"    "kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1" "install kubectl"
check "docker"     "command -v docker"     "docker --version"              "optional - only for the ECR bonus"
check "credentials" "aws sts get-caller-identity" "aws sts get-caller-identity --query Arn --output text" "run: aws configure"

echo
echo "region: ${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo 'not set')}}"
echo "passed: $ok   failed: $fail"

if [ "$fail" -gt 0 ]; then
  echo
  echo "Fix the items above before starting Lab 01."
  echo "(docker is optional - ignore it if that is the only failure)"
  exit 1
fi
