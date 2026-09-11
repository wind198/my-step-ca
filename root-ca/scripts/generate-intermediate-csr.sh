#!/usr/bin/env bash
# Create Intermediate CA cert signed by Root; Intermediate key in Intermediate KMS.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: generate-intermediate-csr.sh \
  --root-cert PATH --root-kms-key-id ID \
  --intermediate-kms-key-id ID --output DIR \
  [--common-name NAME] [--region REGION]

Creates intermediate_ca.crt (Root-signed). Keys remain in KMS.
EOF
  exit 1
}

ROOT_CERT=""
ROOT_KMS=""
INT_KMS=""
OUT=""
CN="Example Corp Intermediate CA"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root-cert) ROOT_CERT="${2:-}"; shift 2 ;;
    --root-kms-key-id|--root-kms-arn) ROOT_KMS="${2:-}"; shift 2 ;;
    --intermediate-kms-key-id|--kms-key-arn|--kms-key-id) INT_KMS="${2:-}"; shift 2 ;;
    --output) OUT="${2:-}"; shift 2 ;;
    --common-name) CN="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

[[ -n "$ROOT_CERT" && -n "$ROOT_KMS" && -n "$INT_KMS" && -n "$OUT" ]] || usage
[[ -f "$ROOT_CERT" ]] || { echo "root cert missing" >&2; exit 1; }
mkdir -p "$OUT"
command -v step >/dev/null || { echo "step CLI required" >&2; exit 1; }

aws kms describe-key --key-id "$INT_KMS" >/dev/null

step certificate create --profile intermediate-ca \
  --kms "awskms:region=${REGION}" \
  --ca "$ROOT_CERT" \
  --ca-key "awskms:key-id=${ROOT_KMS}" \
  --key "awskms:key-id=${INT_KMS}" \
  --not-after 43800h \
  --force \
  "$CN" "$OUT/intermediate_ca.crt"

echo "awskms:key-id=${INT_KMS}" > "$OUT/intermediate_ca.kms"
echo "Intermediate cert: $OUT/intermediate_ca.crt"
