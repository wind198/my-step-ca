#!/usr/bin/env bash
# External JWK provisioner: issue + renew from admin host via port-forward.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

require_cmd kubectl
require_cmd step
require_cmd openssl
skip_if_ca_unreachable

PASS="$LOCAL/secrets/external-test.password"
[[ -f "$PASS" ]] || { log "SKIP: missing $PASS (re-run make bootstrap-local)"; exit 0; }

if ! kubectl -n "$CA_NS" get cm step-ca-config -o jsonpath='{.data.ca\.json}' \
  | jq -e '.authority.provisioners[] | select(.name=="external-test")' >/dev/null; then
  log "SKIP: external-test JWK provisioner not configured"
  exit 0
fi

trap stop_port_forward EXIT
start_port_forward

CN="external-app.example.internal"
ROOT_CRT="$LOCAL/certs/root_ca.crt"

step ca bootstrap --ca-url "$CA_LOCAL_URL" --fingerprint \
  "$(step certificate fingerprint "$ROOT_CRT")" --force 2>/dev/null || true

issue() {
  local crt="$1" key="$2"
  step ca certificate "$CN" "$crt" "$key" \
    --provisioner external-test \
    --provisioner-password-file "$PASS" \
    --ca-url "$CA_LOCAL_URL" \
    --root "$ROOT_CRT" \
    --not-after 1h \
    --force
}

issue "$OUT_DIR/jwk-a.crt" "$OUT_DIR/jwk-a.key"
sleep 2
issue "$OUT_DIR/jwk-b.crt" "$OUT_DIR/jwk-b.key"

assert_chain "$OUT_DIR/jwk-a.crt"
assert_chain "$OUT_DIR/jwk-b.crt"
a="$(not_after_epoch "$OUT_DIR/jwk-a.crt")"
b="$(not_after_epoch "$OUT_DIR/jwk-b.crt")"
[[ "$b" -ge "$a" ]] || die "JWK renew notAfter regression"
log "external 03_jwk_issue_and_renew PASS"
