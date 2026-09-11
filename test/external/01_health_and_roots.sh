#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

require_cmd kubectl
require_cmd curl
require_cmd openssl
skip_if_ca_unreachable
trap stop_port_forward EXIT
start_port_forward

assert_health "$CA_LOCAL_URL"
assert_roots_match "$CA_LOCAL_URL"
log "external 01_health_and_roots PASS"
