#!/usr/bin/env bash
# Unauthenticated sign attempt must fail.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

require_cmd kubectl
require_cmd curl
skip_if_ca_unreachable

trap stop_port_forward EXIT
start_port_forward

# POST without token to sign endpoint should not succeed
code="$(curl -sk -o "$OUT_DIR/deny-body.txt" -w '%{http_code}' \
  -X POST "$CA_LOCAL_URL/1.0/sign" \
  -H 'Content-Type: application/json' \
  -d '{}' || true)"
if [[ "$code" == "200" ]]; then
  die "unauthenticated /1.0/sign returned 200"
fi
log "deny without auth: HTTP $code (expected non-200)"
log "external 04_deny_without_auth PASS"
