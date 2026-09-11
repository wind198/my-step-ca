#!/usr/bin/env bash
# Run all scripts in a suite directory in lexical order.
set -euo pipefail
SUITE_DIR="$(cd "$(dirname "$0")/$1" && pwd)"
shift || true
for s in "$SUITE_DIR"/[0-9]*.sh; do
  [[ -f "$s" ]] || continue
  echo "----- RUN $s -----"
  bash "$s"
done
echo "----- SUITE DONE: $SUITE_DIR -----"
