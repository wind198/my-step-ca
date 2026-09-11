#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AWS_LOCAL="$ROOT/infrastructure/aws/local"
LOCAL="$ROOT/local"
mkdir -p "$LOCAL"
cd "$AWS_LOCAL"
terraform output -json > "$LOCAL/terraform-outputs.json"
echo "wrote $LOCAL/terraform-outputs.json"
jq '{root_ca_kms_key_id, intermediate_ca_kms_key_id, pki_admin_role_arn, step_ca_role_arn}' "$LOCAL/terraform-outputs.json"
