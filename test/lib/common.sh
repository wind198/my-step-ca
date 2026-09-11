#!/usr/bin/env bash
# Shared helpers for leaf workflow integration tests.
# shellcheck disable=SC2034

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
LOCAL="${LOCAL:-$REPO_ROOT/local}"
OUT_DIR="${OUT_DIR:-$LOCAL/test-out}"
CA_NS="${CA_NS:-step-ca}"
CA_INCLUSTER_URL="${CA_INCLUSTER_URL:-https://step-ca.step-ca.svc.cluster.local}"
PF_LOCAL_PORT="${PF_LOCAL_PORT:-19000}"
CA_LOCAL_URL="${CA_LOCAL_URL:-https://127.0.0.1:${PF_LOCAL_PORT}}"

mkdir -p "$OUT_DIR"

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

# Exit 0 with message when CA / cluster not ready (make test stays green in CI without cluster).
skip_if_ca_unreachable() {
  if ! kubectl get ns "$CA_NS" >/dev/null 2>&1; then
    log "SKIP: namespace $CA_NS not found (run make deploy-dev)"
    exit 0
  fi
  if ! kubectl -n "$CA_NS" get deploy step-ca >/dev/null 2>&1; then
    log "SKIP: step-ca deploy missing"
    exit 0
  fi
  local ready
  ready="$(kubectl -n "$CA_NS" get deploy step-ca -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
  if [[ -z "$ready" || "$ready" == "0" ]]; then
    log "SKIP: step-ca not Ready"
    exit 0
  fi
}

ca_pod() {
  kubectl -n "$CA_NS" get pod -l app.kubernetes.io/name=step-ca -o jsonpath='{.items[0].metadata.name}'
}

# Start port-forward; writes PID to OUT_DIR/pf.pid
start_port_forward() {
  local pod
  pod="$(ca_pod)"
  [[ -n "$pod" ]] || die "no step-ca pod"
  kubectl -n "$CA_NS" port-forward "pod/${pod}" "${PF_LOCAL_PORT}:9000" \
    >"$OUT_DIR/pf.log" 2>&1 &
  echo $! >"$OUT_DIR/pf.pid"
  local i
  for i in $(seq 1 30); do
    if curl -fsSk "$CA_LOCAL_URL/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  die "port-forward health failed (see $OUT_DIR/pf.log)"
}

stop_port_forward() {
  if [[ -f "$OUT_DIR/pf.pid" ]]; then
    kill "$(cat "$OUT_DIR/pf.pid")" 2>/dev/null || true
    rm -f "$OUT_DIR/pf.pid"
  fi
}

assert_health() {
  local url="$1"
  curl -fsSk "$url/health" | grep -q '"status":"ok"\|ok' \
    || curl -fsSk "$url/health" | grep -qi ok \
    || die "health check failed at $url"
  log "health ok ($url)"
}

assert_roots_match() {
  local url="$1"
  local expected="${2:-$LOCAL/certs/root_ca.crt}"
  [[ -f "$expected" ]] || die "missing root cert $expected"
  curl -fsSk "$url/roots.pem" -o "$OUT_DIR/roots-fetched.pem"
  # Compare subject / fingerprint rather than exact PEM formatting
  local want got
  want="$(openssl x509 -in "$expected" -noout -fingerprint -sha256 | cut -d= -f2)"
  got="$(openssl x509 -in "$OUT_DIR/roots-fetched.pem" -noout -fingerprint -sha256 | cut -d= -f2)"
  [[ "$want" == "$got" ]] || die "roots.pem fingerprint mismatch"
  log "roots.pem matches local Root"
}

assert_chain() {
  local leaf="$1"
  local root="${2:-$LOCAL/certs/root_ca.crt}"
  local intc="${3:-$LOCAL/certs/intermediate_ca.crt}"
  cat "$intc" "$root" >"$OUT_DIR/chain.pem"
  openssl verify -CAfile "$OUT_DIR/chain.pem" "$leaf" || die "chain verify failed for $leaf"
  log "chain ok ($leaf)"
}

not_after_epoch() {
  date -d "$(openssl x509 -in "$1" -noout -enddate | cut -d= -f2)" +%s
}

# Load smallstep/step-cli into kind when Docker Hub from the node is flaky.
# Only the image ref is printed on stdout (for $(step_cli_img)); all else → stderr.
ensure_step_cli_image() {
  local img="${STEP_CLI_IMAGE:-smallstep/step-cli:0.28.3}"
  local tag_kind="smallstep/step-cli:kind"
  local stamp="$OUT_DIR/.step-cli-kind-loaded"
  if ! docker exec kind-control-plane true >/dev/null 2>&1; then
    log "SKIP: kind-control-plane not running (cannot load step-cli)"
    exit 0
  fi
  # ctr may list docker.io/ prefix; match substring only
  if docker exec kind-control-plane ctr -n k8s.io images ls 2>/dev/null | grep -F 'step-cli:kind' >/dev/null; then
    touch "$stamp"
    echo "$tag_kind"
    return 0
  fi
  log "loading $img into kind as $tag_kind ..."
  (
    set -e
    docker pull --platform linux/amd64 "$img"
    printf 'FROM %s\n' "$img" | docker build --platform linux/amd64 -t "$tag_kind" -
    docker save "$tag_kind" -o /tmp/step-cli-kind.tar
    docker cp /tmp/step-cli-kind.tar kind-control-plane:/step-cli-kind.tar
    docker exec kind-control-plane ctr -n k8s.io images import /step-cli-kind.tar
  ) >&2
  touch "$stamp"
  echo "$tag_kind"
}

STEP_CLI_IMG=""
step_cli_img() {
  if [[ -z "$STEP_CLI_IMG" ]]; then
    STEP_CLI_IMG="$(ensure_step_cli_image)"
  fi
  echo "$STEP_CLI_IMG"
}

# step-ca K8sSA expects legacy tokens (iss=kubernetes/serviceaccount), not bound tokens.
ensure_legacy_sa_token() {
  local ns="$1" sa="$2" secret="${3:-${sa}-token}"
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns"
  kubectl -n "$ns" get sa "$sa" >/dev/null 2>&1 || kubectl -n "$ns" create sa "$sa"
  if ! kubectl -n "$ns" get secret "$secret" >/dev/null 2>&1; then
    kubectl -n "$ns" apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret}
  annotations:
    kubernetes.io/service-account.name: ${sa}
type: kubernetes.io/service-account-token
EOF
    local i
    for i in $(seq 1 30); do
      if kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; then
        break
      fi
      sleep 1
    done
  fi
  kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.token}' | grep -q . \
    || die "legacy SA token secret $ns/$secret missing token data"
}
