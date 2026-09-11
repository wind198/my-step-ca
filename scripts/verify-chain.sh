#!/usr/bin/env bash
set -euo pipefail
exec "$(cd "$(dirname "$0")/.." && pwd)/root-ca/scripts/verify-chain.sh" "$@"
