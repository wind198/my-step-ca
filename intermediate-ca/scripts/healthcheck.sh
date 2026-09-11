#!/usr/bin/env bash
set -euo pipefail
URL="${1:-https://127.0.0.1:9000/health}"
curl -fsS -k "$URL" || curl -fsS "$URL"
echo
