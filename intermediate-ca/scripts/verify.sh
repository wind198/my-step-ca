#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-}"
INT="${2:-}"
[[ -n "$ROOT" && -n "$INT" ]] || { echo "Usage: verify.sh ROOT.crt INTERMEDIATE.crt" >&2; exit 1; }
openssl verify -CAfile "$ROOT" "$INT"
