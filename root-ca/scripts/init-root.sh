#!/usr/bin/env bash
# Initialize Root CA certificate; private key stays in Root KMS.
# Official pattern: https://smallstep.com/docs/step-ca/cryptographic-protection/
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: init-root.sh --kms-key-id ID --output DIR [--common-name NAME] [--region REGION]

--kms-key-id may be a key id, alias, or ARN.
Requires: step CLI + step-kms-plugin; AWS creds (assumed pki-admin).
For LocalStack set AWS_ENDPOINT_URL.
EOF
  exit 1
}

KMS_ID=""
OUT=""
CN="Example Corp Root CA"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kms-key-id|--kms-key-arn) KMS_ID="${2:-}"; shift 2 ;;
    --output) OUT="${2:-}"; shift 2 ;;
    --common-name) CN="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

[[ -n "$KMS_ID" && -n "$OUT" ]] || usage
mkdir -p "$OUT"
command -v step >/dev/null || { echo "step CLI required" >&2; exit 1; }

aws kms describe-key --key-id "$KMS_ID" >/dev/null

KEY_URI="awskms:key-id=${KMS_ID}"
# If ARN passed, also accept awskms:arn= form via key-id= full ARN (SDK accepts ARN as key-id)

step certificate create --profile root-ca \
  --kms "awskms:region=${REGION}" \
  --key "${KEY_URI}" \
  --not-after 87600h \
  --force \
  "$CN" "$OUT/root_ca.crt"

echo "${KEY_URI}" > "$OUT/root_ca.kms"
echo "Root CA certificate: $OUT/root_ca.crt"
