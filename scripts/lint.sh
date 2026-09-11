#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "lint: helm + basic secret scan"
"$ROOT/scripts/validate.sh" >/dev/null || true
# Refuse tracked private keys / obvious secrets
if git -C "$ROOT" ls-files 2>/dev/null | grep -E '\.(key|pem|p12|pfx)$|credentials\.json|password\.txt' ; then
  echo "ERROR: secret-like files tracked" >&2
  exit 1
fi
echo "lint ok"
