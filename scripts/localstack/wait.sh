#!/usr/bin/env bash
set -euo pipefail
ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
echo "waiting for LocalStack at $ENDPOINT ..."
for i in $(seq 1 60); do
  if curl -fsS "$ENDPOINT/_localstack/health" >/dev/null 2>&1; then
    echo "LocalStack ready"
    exit 0
  fi
  sleep 2
done
echo "LocalStack did not become ready" >&2
exit 1
