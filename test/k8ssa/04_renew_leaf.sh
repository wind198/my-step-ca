#!/usr/bin/env bash
# Renew leaf: two successive issues; second notAfter >= first.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

require_cmd kubectl
require_cmd openssl
skip_if_ca_unreachable

if ! kubectl -n "$CA_NS" get cm step-ca-config -o jsonpath='{.data.ca\.json}' \
  | jq -e '.authority.provisioners[] | select(.name=="kube-default")' >/dev/null; then
  log "SKIP: kube-default K8SSA provisioner not configured"
  exit 0
fi

NS_TEST=payments
SA_TEST=payments-api
SA_SECRET="${SA_TEST}-token"
CN="${SA_TEST}.${NS_TEST}.svc.cluster.local"

ensure_legacy_sa_token "$NS_TEST" "$SA_TEST" "$SA_SECRET"
kubectl -n "$NS_TEST" create configmap test-ca-root \
  --from-file=root_ca.crt="$LOCAL/certs/root_ca.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

issue_once() {
  local job="$1" out="$2"
  local cli_img
  cli_img="$(step_cli_img)"
  kubectl -n "$NS_TEST" delete job "$job" --ignore-not-found --wait=true 2>/dev/null || true
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NS_TEST}
spec:
  backoffLimit: 1
  template:
    spec:
      serviceAccountName: ${SA_TEST}
      restartPolicy: Never
      containers:
        - name: step
          image: ${cli_img}
          imagePullPolicy: Never
          command:
            - /bin/sh
            - -c
            - |
              set -e
              step ca certificate "${CN}" /tmp/leaf.crt /tmp/leaf.key --provisioner kube-default --ca-url "${CA_INCLUSTER_URL}" --root /ca/root_ca.crt --k8ssa-token-path /var/run/secrets/sa/token --not-after 1h --force
              cat /tmp/leaf.crt
          volumeMounts:
            - name: ca
              mountPath: /ca
              readOnly: true
            - name: sa-token
              mountPath: /var/run/secrets/sa
              readOnly: true
      volumes:
        - name: ca
          configMap:
            name: test-ca-root
        - name: sa-token
          secret:
            secretName: ${SA_SECRET}
EOF
  kubectl -n "$NS_TEST" wait --for=condition=complete "job/${job}" --timeout=180s \
    || { kubectl -n "$NS_TEST" logs "job/${job}" --tail=40 || true; die "renew issue job $job failed"; }
  kubectl -n "$NS_TEST" logs "job/${job}" | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' >"$out"
  [[ -s "$out" ]] || die "empty cert $out"
}

issue_once test-k8ssa-renew-a "$OUT_DIR/k8ssa-renew-a.crt"
sleep 2
issue_once test-k8ssa-renew-b "$OUT_DIR/k8ssa-renew-b.crt"

assert_chain "$OUT_DIR/k8ssa-renew-a.crt"
assert_chain "$OUT_DIR/k8ssa-renew-b.crt"
a="$(not_after_epoch "$OUT_DIR/k8ssa-renew-a.crt")"
b="$(not_after_epoch "$OUT_DIR/k8ssa-renew-b.crt")"
[[ "$b" -ge "$a" ]] || die "renewed cert notAfter $b < prior $a"
log "k8ssa 04_renew_leaf PASS"
