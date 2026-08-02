#!/usr/bin/env bash
# Destroy every lab, in the correct reverse order.
set -u
cd "$(dirname "$0")/../code" || exit 1

for dir in 06-kubernetes 05-eks 04-ecr 03-ec2-ebs 02-iam 01-s3-state; do
  if [ -d "$dir" ] && [ -d "$dir/.terraform" ]; then
    echo
    echo "=== destroying $dir ==="
    (cd "$dir" && terraform destroy -auto-approve) || echo "!! $dir failed - see labs/07-teardown.md"
  else
    echo "--- skipping $dir (never initialised) ---"
  fi
done

echo
echo "Now VERIFY manually - Kubernetes-created load balancers and volumes are"
echo "invisible to Terraform state:"
echo "  aws eks list-clusters --region ap-south-1"
echo "  aws elb describe-load-balancers --region ap-south-1"
echo "  aws ec2 describe-volumes --region ap-south-1 --filters Name=status,Values=available"
