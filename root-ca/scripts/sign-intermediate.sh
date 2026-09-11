#!/usr/bin/env bash
# Optional CSR-only path kept for renewal runbooks.
# Prefer generate-intermediate-csr.sh (creates signed Intermediate in one step).
set -euo pipefail
echo "Use generate-intermediate-csr.sh for KMS-backed Intermediate creation." >&2
echo "For CSR-only renewal flows, see docs/runbooks/intermediate-renewal.md" >&2
exit 0
