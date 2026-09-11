#!/usr/bin/env bash
# Deploy step-ca to kind with LocalStack KMS credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCAL="$ROOT/local"
CHART="$ROOT/deploy/helm/step-ca"
NS=step-ca
ENDPOINT_HOST="${LOCALSTACK_HOST:-}"

command -v kubectl >/dev/null
command -v helm >/dev/null
kubectl config current-context | grep -q kind || echo "WARN: context is not kind: $(kubectl config current-context)"

[[ -f "$LOCAL/certs/root_ca.crt" && -f "$LOCAL/certs/intermediate_ca.crt" && -f "$LOCAL/config/ca.json" ]] \
  || { echo "missing bootstrap artifacts — run make bootstrap-local" >&2; exit 1; }

mkdir -p "$LOCAL/config/templates"
[[ -f "$LOCAL/config/templates/k8ssa-workload.json" ]] || \
  cp "$ROOT/intermediate-ca/config/templates/k8ssa-workload.json" "$LOCAL/config/templates/k8ssa-workload.json"
if [[ ! -f "$LOCAL/config/templates/external-leaf.json" ]]; then
  cat > "$LOCAL/config/templates/external-leaf.json" <<'TMPL'
{
  "subject": {"commonName": {{ toJson .Subject.CommonName }}},
  "sans": {{ toJson .SANs }},
  "keyUsage": ["digitalSignature", "keyEncipherment"],
  "extKeyUsage": ["serverAuth", "clientAuth"]
}
TMPL
fi

# Ensure single-arch image present on kind node (Docker Hub DNS from kind is flaky)
IMG_SRC="smallstep/step-ca:0.28.3"
IMG_KIND="smallstep/step-ca:kind"
if ! docker exec kind-control-plane ctr -n k8s.io images ls | grep -q "smallstep/step-ca:kind"; then
  echo "building/loading $IMG_KIND into kind..."
  docker pull --platform linux/amd64 "$IMG_SRC"
  printf 'FROM smallstep/step-ca:0.28.3\n' | docker build --platform linux/amd64 -t "$IMG_KIND" -
  docker save "$IMG_KIND" -o /tmp/step-ca-kind.tar
  docker cp /tmp/step-ca-kind.tar kind-control-plane:/step-ca-kind.tar
  docker exec kind-control-plane ctr -n k8s.io images import /step-ca-kind.tar
fi

# Resolve LocalStack IP reachable from kind pods
if [[ -z "$ENDPOINT_HOST" ]]; then
  if docker inspect step-ca-localstack >/dev/null 2>&1; then
    # Prefer docker bridge gateway (Linux kind → host services)
    ENDPOINT_HOST="$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || true)"
  fi
  ENDPOINT_HOST="${ENDPOINT_HOST:-172.17.0.1}"
fi
ENDPOINT_URL="http://${ENDPOINT_HOST}:4566"
echo "LocalStack endpoint for pods: $ENDPOINT_URL"

# Assume step-ca role and create K8s secret
"$ROOT/scripts/localstack/assume-role.sh" step-ca
# shellcheck disable=SC1091
source "$LOCAL/.aws-session"

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

CM_ARGS=(
  --from-file=ca.json="$LOCAL/config/ca.json"
  --from-file=root_ca.crt="$LOCAL/certs/root_ca.crt"
  --from-file=intermediate_ca.crt="$LOCAL/certs/intermediate_ca.crt"
)
[[ -f "$LOCAL/config/templates/k8ssa-workload.json" ]] && \
  CM_ARGS+=(--from-file=k8ssa-workload.json="$LOCAL/config/templates/k8ssa-workload.json")
[[ -f "$LOCAL/config/templates/external-leaf.json" ]] && \
  CM_ARGS+=(--from-file=external-leaf.json="$LOCAL/config/templates/external-leaf.json")

kubectl -n "$NS" create configmap step-ca-config \
  "${CM_ARGS[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ConfigMap updates do not always restart pods — force pick-up of certs/provisioners
kubectl -n "$NS" rollout restart deploy/step-ca 2>/dev/null || true

kubectl -n "$NS" create secret generic step-ca-aws \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

INT_KMS="$(jq -r '.intermediate_ca_kms_key_id.value' "$LOCAL/terraform-outputs.json")"

helm upgrade --install step-ca "$CHART" \
  --namespace "$NS" \
  -f "$CHART/values.yaml" \
  -f "$CHART/values-dev.yaml" \
  --set "kms.keyId=${INT_KMS}" \
  --set "kms.endpointUrl=${ENDPOINT_URL}" \
  --set "aws.credentialsSecretName=step-ca-aws" \
  --wait --timeout 180s

kubectl -n "$NS" rollout status deploy/step-ca --timeout=180s
kubectl -n "$NS" get pods -o wide

POD="$(kubectl -n "$NS" get pod -l app.kubernetes.io/name=step-ca -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "$NS" port-forward "pod/${POD}" 19000:9000 >/tmp/step-ca-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3
if curl -fsSk https://127.0.0.1:19000/health; then
  echo
  echo "health ok"
else
  echo "health check failed" >&2
  kubectl -n "$NS" logs -l app.kubernetes.io/name=step-ca --tail=80 || true
  exit 1
fi
