#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHART="$ROOT/deploy/helm/step-ca"
helm lint "$CHART" -f "$CHART/values.yaml"
for env in values-dev values-prod; do
  helm template step-ca "$CHART" -f "$CHART/values.yaml" -f "$CHART/${env}.yaml" >/dev/null
  echo "template ok: $env"
done
if command -v terraform >/dev/null; then
  terraform -chdir="$ROOT/infrastructure/aws/local" fmt -check -recursive || terraform -chdir="$ROOT/infrastructure/aws/local" fmt -recursive
  terraform -chdir="$ROOT/infrastructure/aws/prod" fmt -check -recursive || terraform -chdir="$ROOT/infrastructure/aws/prod" fmt -recursive
  terraform -chdir="$ROOT/infrastructure/aws/modules" fmt -check -recursive || terraform -chdir="$ROOT/infrastructure/aws/modules" fmt -recursive
fi
echo "validate ok"
