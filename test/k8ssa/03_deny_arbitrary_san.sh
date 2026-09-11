#!/usr/bin/env bash
# Requesting an arbitrary SAN must not yield that identity (template forces SA-derived SAN).
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
EVIL=evil.example.internal
ALLOWED="${SA_TEST}.${NS_TEST}.svc.cluster.local"

ensure_legacy_sa_token "$NS_TEST" "$SA_TEST" "$SA_SECRET"
kubectl -n "$NS_TEST" create configmap test-ca-root \
  --from-file=root_ca.crt="$LOCAL/certs/root_ca.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

JOB=test-k8ssa-deny
kubectl -n "$NS_TEST" delete job "$JOB" --ignore-not-found --wait=true 2>/dev/null || true

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
          command:
            - /bin/sh
            - -c
            - |
              set -e
              mkdir -p /out
              if step ca certificate "${EVIL}" /out/leaf.crt /out/leaf.key --san "${EVIL}" --provisioner kube-default --ca-url "${CA_INCLUSTER_URL}" --root /ca/root_ca.crt --k8ssa-token-path /var/run/secrets/sa/token --not-after 1h --force; then
                step certificate inspect /out/leaf.crt --format text > /out/text.txt
                if grep -q "${EVIL}" /out/text.txt; then
                  echo "DENY_FAIL: evil SAN present in cert"
                  exit 1
                fi
                if ! grep -q "${ALLOWED}" /out/text.txt; then
                  echo "DENY_FAIL: expected allowed SAN missing"
                  exit 1
                fi
                echo "DENY_OK: template overwrote CSR to allowed SAN"
                cat /out/leaf.crt
              else
                echo "DENY_OK: request rejected"
              fi
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
  || { kubectl -n "$NS_TEST" logs "job/${JOB}" --tail=80 || true; die "deny job failed"; }

kubectl -n "$NS_TEST" logs "job/${JOB}" | tee "$OUT_DIR/k8ssa-deny.log" | grep -q DENY_OK \
  || die "expected DENY_OK"
log "k8ssa 03_deny_arbitrary_san PASS"
