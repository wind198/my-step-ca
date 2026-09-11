#!/usr/bin/env bash
# Issue leaf via K8SSA for allow-listed SA → SAN mapping.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

require_cmd kubectl
require_cmd openssl
skip_if_ca_unreachable

# Need kube-default provisioner
if ! kubectl -n "$CA_NS" get cm step-ca-config -o jsonpath='{.data.ca\.json}' \
  | jq -e '.authority.provisioners[] | select(.name=="kube-default")' >/dev/null; then
  log "SKIP: kube-default K8SSA provisioner not in ca.json (re-run make bootstrap-local && make deploy-dev)"
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

JOB=test-k8ssa-issue
kubectl -n "$NS_TEST" delete job "$JOB" --ignore-not-found --wait=true 2>/dev/null || true
kubectl -n "$NS_TEST" delete pod -l job-name="$JOB" --ignore-not-found 2>/dev/null || true

CLI_IMG="$(step_cli_img)"

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB}
  namespace: ${NS_TEST}
spec:
  backoffLimit: 1
  template:
    spec:
      serviceAccountName: ${SA_TEST}
      restartPolicy: Never
      containers:
        - name: step
          image: ${CLI_IMG}
          imagePullPolicy: Never
          env:
            - name: STEPPATH
              value: /tmp/step
          command:
            - /bin/sh
            - -c
            - |
              set -e
              mkdir -p /out /tmp/step
              step ca certificate "${CN}" /out/leaf.crt /out/leaf.key --provisioner kube-default --ca-url "${CA_INCLUSTER_URL}" --root /ca/root_ca.crt --k8ssa-token-path /var/run/secrets/sa/token --not-after 1h --force
              cat /out/leaf.crt
          volumeMounts:
            - name: ca
              mountPath: /ca
              readOnly: true
            - name: out
              mountPath: /out
            - name: sa-token
              mountPath: /var/run/secrets/sa
              readOnly: true
      volumes:
        - name: ca
          configMap:
            name: test-ca-root
        - name: out
          emptyDir: {}
        - name: sa-token
          secret:
            secretName: ${SA_SECRET}
EOF

kubectl -n "$NS_TEST" wait --for=condition=complete "job/${JOB}" --timeout=180s \
  || { kubectl -n "$NS_TEST" logs "job/${JOB}" --tail=80 || true; die "K8SSA issue job failed"; }

kubectl -n "$NS_TEST" logs "job/${JOB}" | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' >"$OUT_DIR/k8ssa-leaf.crt"
[[ -s "$OUT_DIR/k8ssa-leaf.crt" ]] || die "empty leaf cert from job logs"
openssl x509 -in "$OUT_DIR/k8ssa-leaf.crt" -noout -subject | grep -q "$CN" \
  || openssl x509 -in "$OUT_DIR/k8ssa-leaf.crt" -noout -text | grep -q "$CN" \
  || die "leaf SAN/CN missing $CN"
assert_chain "$OUT_DIR/k8ssa-leaf.crt"
log "k8ssa 02_issue_allowed_san PASS"
