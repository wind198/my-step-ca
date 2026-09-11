#!/usr/bin/env bash
# Assume pki-admin or step-ca role against LocalStack; write session env to local/.aws-session
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCAL="$ROOT/local"
ROLE_KIND="${1:-admin}"
ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ENDPOINT_URL="$ENDPOINT"

OUTS="$LOCAL/terraform-outputs.json"
[[ -f "$OUTS" ]] || { echo "missing $OUTS — run make tf-apply-local first" >&2; exit 1; }

if [[ "$ROLE_KIND" == "admin" ]]; then
  ROLE_ARN="$(jq -r '.pki_admin_role_arn.value' "$OUTS")"
  SESSION="pki-admin-local"
else
  ROLE_ARN="$(jq -r '.step_ca_role_arn.value' "$OUTS")"
  SESSION="step-ca-local"
fi

CREDS="$(aws --endpoint-url="$ENDPOINT" sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "$SESSION" \
  --duration-seconds 3600 \
  --output json)"

mkdir -p "$LOCAL"
cat > "$LOCAL/.aws-session" <<EOF
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
export AWS_ENDPOINT_URL=${ENDPOINT}
export AWS_EC2_METADATA_DISABLED=true
EOF

echo "Assumed $ROLE_ARN → $LOCAL/.aws-session"
echo "source $LOCAL/.aws-session"
