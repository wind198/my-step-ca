#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: verify-chain.sh --root PATH --intermediate PATH" >&2
  exit 1
}

ROOT=""
INT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --intermediate) INT="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$ROOT" && -n "$INT" ]] || usage

openssl verify -CAfile "$ROOT" "$INT"
echo "chain ok"
