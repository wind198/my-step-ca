#!/usr/bin/env bash
# Bootstrap Root + Intermediate using LocalStack KMS (admin assumed role).
# Local ca.json includes ACME + K8SSA + JWK (dev-only) for leaf workflow tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCAL="$ROOT/local"
OUTS="$LOCAL/terraform-outputs.json"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

[[ -f "$LOCAL/.aws-session" ]] || { echo "run make assume-admin first" >&2; exit 1; }
# shellcheck disable=SC1091
source "$LOCAL/.aws-session"

command -v step >/dev/null || { echo "step CLI missing" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq missing" >&2; exit 1; }

ROOT_KMS="$(jq -r '.root_ca_kms_key_id.value' "$OUTS")"
INT_KMS="$(jq -r '.intermediate_ca_kms_key_id.value' "$OUTS")"

mkdir -p "$LOCAL/certs" "$LOCAL/config/templates" "$LOCAL/secrets"

echo "==> Root CA (KMS=$ROOT_KMS)"
"$ROOT/root-ca/scripts/init-root.sh" \
  --kms-key-id "$ROOT_KMS" \
  --output "$LOCAL/certs" \
  --region "$REGION"

echo "==> Intermediate CA (KMS=$INT_KMS)"
"$ROOT/root-ca/scripts/generate-intermediate-csr.sh" \
  --root-cert "$LOCAL/certs/root_ca.crt" \
  --root-kms-key-id "$ROOT_KMS" \
  --intermediate-kms-key-id "$INT_KMS" \
  --output "$LOCAL/certs" \
  --region "$REGION"

"$ROOT/root-ca/scripts/verify-chain.sh" \
  --root "$LOCAL/certs/root_ca.crt" \
  --intermediate "$LOCAL/certs/intermediate_ca.crt"

# K8SSA X.509 template — SAN forced from SA token (deny arbitrary CSR SANs)
cp -f "$ROOT/intermediate-ca/config/templates/k8ssa-workload.json" \
  "$LOCAL/config/templates/k8ssa-workload.json"

# Dev-only JWK password (gitignored via local/**)
if [[ ! -f "$LOCAL/secrets/external-test.password" ]]; then
  openssl rand -base64 24 > "$LOCAL/secrets/external-test.password"
fi

# Kind SA signing pubkey for K8SSA (optional until cluster exists)
SA_PUB="$LOCAL/secrets/k8s-sa.pub"
if [[ ! -f "$SA_PUB" ]]; then
  if docker exec kind-control-plane cat /etc/kubernetes/pki/sa.pub >"$SA_PUB" 2>/dev/null; then
    echo "fetched kind SA public key → $SA_PUB"
  else
    echo "WARN: kind SA pubkey unavailable — K8SSA provisioner skipped until cluster is up" >&2
  fi
fi

CA_JSON="$LOCAL/config/ca.json"
cat > "$CA_JSON" <<EOF
{
  "root": "/home/step/certs/root_ca.crt",
  "crt": "/home/step/certs/intermediate_ca.crt",
  "key": "awskms:key-id=${INT_KMS}",
  "kms": {
    "type": "awskms",
    "uri": "awskms:region=${REGION}"
  },
  "address": ":9000",
  "dnsNames": [
    "step-ca.step-ca.svc.cluster.local",
    "localhost",
    "127.0.0.1"
  ],
  "logger": { "format": "json" },
  "db": {
    "type": "badgerv2",
    "dataSource": "/home/step/db"
  },
  "authority": {
    "claims": {
      "minTLSCertDuration": "5m",
      "maxTLSCertDuration": "24h",
      "defaultTLSCertDuration": "1h"
    },
    "provisioners": [
      {
        "type": "ACME",
        "name": "acme"
      }
    ]
  }
}
EOF

echo "==> Add JWK provisioner external-test (dev-only)"
EXTERNAL_TMPL="$LOCAL/config/templates/external-leaf.json"
cat > "$EXTERNAL_TMPL" <<'TMPL'
{
  "subject": {"commonName": {{ toJson .Subject.CommonName }}},
  "sans": {{ toJson .SANs }},
  "keyUsage": ["digitalSignature", "keyEncipherment"],
  "extKeyUsage": ["serverAuth", "clientAuth"]
}
TMPL

# Offline config edit: newer step CLI wants --ca-url/--root; use a closed port to avoid admin API.
# Absolute paths required so step does not fall back to defaults (port 9000).
CA_JSON_ABS="$(cd "$(dirname "$CA_JSON")" && pwd)/$(basename "$CA_JSON")"
ROOT_CRT_ABS="$(cd "$LOCAL/certs" && pwd)/root_ca.crt"
CA_URL_FLAG=(--ca-url "https://127.0.0.1:9" --root "$ROOT_CRT_ABS" --ca-config "$CA_JSON_ABS")

step ca provisioner remove external-test "${CA_URL_FLAG[@]}" 2>/dev/null || true
step ca provisioner add external-test \
  --type JWK \
  --create \
  --password-file "$LOCAL/secrets/external-test.password" \
  --x509-template "$EXTERNAL_TMPL" \
  "${CA_URL_FLAG[@]}"

jq --arg tmpl "/home/step/templates/external-leaf.json" '
  (.authority.provisioners[] | select(.name=="external-test")).options.x509.templateFile = $tmpl
' "$CA_JSON" > "${CA_JSON}.tmp" && mv "${CA_JSON}.tmp" "$CA_JSON"

if [[ -f "$SA_PUB" ]]; then
  echo "==> Add K8SSA provisioner kube-default"
  step ca provisioner remove kube-default "${CA_URL_FLAG[@]}" 2>/dev/null || true
  step ca provisioner add kube-default \
    --type K8SSA \
    --public-key "$SA_PUB" \
    --x509-template "$LOCAL/config/templates/k8ssa-workload.json" \
    "${CA_URL_FLAG[@]}"
  jq --arg tmpl "/home/step/templates/k8ssa-workload.json" '
    (.authority.provisioners[] | select(.name=="kube-default")).options.x509.templateFile = $tmpl
    | (.authority.provisioners[] | select(.name=="kube-default")).options.x509 |= del(.template)
    | (.authority.provisioners[] | select(.name=="kube-default")).claims = {
        "maxTLSCertDuration": "8h",
        "defaultTLSCertDuration": "1h"
      }
  ' "$CA_JSON" > "${CA_JSON}.tmp" && mv "${CA_JSON}.tmp" "$CA_JSON"
fi

# Ensure ACME still first / present
if ! jq -e '.authority.provisioners[] | select(.name=="acme")' "$CA_JSON" >/dev/null; then
  echo "ERROR: ACME provisioner missing" >&2
  exit 1
fi

cp -f "$LOCAL/certs/root_ca.crt" "$LOCAL/root_ca.crt"
cp -f "$LOCAL/certs/intermediate_ca.crt" "$LOCAL/intermediate_ca.crt"

echo "bootstrap complete → $LOCAL"
jq -r '.authority.provisioners[] | "provisioner: \(.type) \(.name)"' "$CA_JSON"
