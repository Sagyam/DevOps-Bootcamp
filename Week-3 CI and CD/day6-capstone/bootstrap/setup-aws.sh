#!/usr/bin/env bash
# One-time per-account setup for the Day 6 capstone.
# Creates: the GitHub OIDC provider, a keyless deploy role for this repo, the two
# roles ECS Express Mode needs, and an ECR repository.
#
# Run it once per student AWS account with the AWS CLI already configured:
#   GITHUB_ORG=your-org GITHUB_REPO=your-repo ./setup-aws.sh
#
# It is idempotent — safe to re-run.
set -euo pipefail

# ---- configure these (or pass as env vars) ----
: "${GITHUB_ORG:?Set GITHUB_ORG to your GitHub org/user}"
: "${GITHUB_REPO:?Set GITHUB_REPO to your repository name}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-day6-capstone}"
GHA_ROLE="${GHA_ROLE:-github-actions-day6}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REPO_ARN="arn:aws:ecr:${AWS_REGION}:${ACCOUNT_ID}:repository/${ECR_REPOSITORY}"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
here="$(cd "$(dirname "$0")" && pwd)"

echo ">> Account: ${ACCOUNT_ID}  Region: ${AWS_REGION}  Repo: ${GITHUB_ORG}/${GITHUB_REPO}"

# 1) GitHub OIDC provider (AWS validates GitHub's cert automatically now; the
#    thumbprint is required by the API but effectively ignored).
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo ">> OIDC provider already exists."
else
  echo ">> Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" >/dev/null
fi

# 2) The keyless deploy role this repo assumes via OIDC.
cat > /tmp/gha-trust.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*" }
    }
  }]
}
JSON

if aws iam get-role --role-name "$GHA_ROLE" >/dev/null 2>&1; then
  echo ">> Role ${GHA_ROLE} exists; updating trust policy..."
  aws iam update-assume-role-policy --role-name "$GHA_ROLE" --policy-document file:///tmp/gha-trust.json
else
  echo ">> Creating role ${GHA_ROLE}..."
  aws iam create-role --role-name "$GHA_ROLE" --assume-role-policy-document file:///tmp/gha-trust.json >/dev/null
fi

# Fill the permissions template with this account's values, then attach inline.
sed -e "s|ECR_REPO_ARN|${ECR_REPO_ARN}|g" -e "s|ACCOUNT_ID|${ACCOUNT_ID}|g" \
    "${here}/github-actions-permissions.json" > /tmp/gha-perms.json
aws iam put-role-policy --role-name "$GHA_ROLE" \
    --policy-name "day6-deploy" --policy-document file:///tmp/gha-perms.json
echo ">> Attached deploy permissions to ${GHA_ROLE}."

# 3) The two roles ECS Express Mode requires.
create_ecs_role() {
  local name="$1" principal="$2" policy_arn="$3"
  cat > /tmp/ecs-trust.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"${principal}"},"Action":"sts:AssumeRole"}]}
JSON
  if ! aws iam get-role --role-name "$name" >/dev/null 2>&1; then
    echo ">> Creating ${name}..."
    aws iam create-role --role-name "$name" --assume-role-policy-document file:///tmp/ecs-trust.json >/dev/null
  else
    echo ">> ${name} already exists."
  fi
  aws iam attach-role-policy --role-name "$name" --policy-arn "$policy_arn"
}

create_ecs_role "ecsTaskExecutionRole" "ecs-tasks.amazonaws.com" \
  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
create_ecs_role "ecsInfrastructureRoleForExpressServices" "ecs.amazonaws.com" \
  "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"

# 4) The ECR repository the pipeline pushes to.
if ! aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo ">> Creating ECR repository ${ECR_REPOSITORY}..."
  aws ecr create-repository --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION" >/dev/null
else
  echo ">> ECR repository already exists."
fi

cat <<SUMMARY

Done. Now set these on the GitHub repo (Settings > Secrets and variables > Actions > Variables):

  AWS_REGION       = ${AWS_REGION}
  AWS_ACCOUNT_ID   = ${ACCOUNT_ID}
  ECR_REPOSITORY   = ${ECR_REPOSITORY}
  ECS_SERVICE      = day6-capstone

Then push a change under day6-capstone/** (or run the workflow manually).
The first run creates the Express Mode service; later runs update it.
SUMMARY
