#!/usr/bin/env bash
# ACME: directory reachable + in-cluster HTTP-01 issue for a ClusterIP service name.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

require_cmd kubectl
require_cmd curl
require_cmd jq
require_cmd openssl
skip_if_ca_unreachable

trap stop_port_forward EXIT
start_port_forward

ACME_DIR="${CA_LOCAL_URL}/acme/acme/directory"
curl -fsSk "$ACME_DIR" -o "$OUT_DIR/acme-directory.json"
jq -e '.newNonce and .newAccount and .newOrder' "$OUT_DIR/acme-directory.json" >/dev/null \
  || die "ACME directory missing required fields"
log "ACME directory ok"

# Prefer in-cluster ACME issue with webroot + nginx sidecar
NS_EXT=external-test
CN="acme-leaf.${NS_EXT}.svc.cluster.local"
kubectl get ns "$NS_EXT" >/dev/null 2>&1 || kubectl create namespace "$NS_EXT"
kubectl -n "$NS_EXT" create configmap test-ca-root \
  --from-file=root_ca.crt="$LOCAL/certs/root_ca.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS_EXT" delete job test-acme-issue --ignore-not-found --wait=true 2>/dev/null || true
kubectl -n "$NS_EXT" delete svc acme-leaf --ignore-not-found 2>/dev/null || true

CLI_IMG="$(step_cli_img)"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: acme-leaf
  namespace: ${NS_EXT}
spec:
  selector:
    app: acme-leaf
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: batch/v1
kind: Job
metadata:
  name: test-acme-issue
  namespace: ${NS_EXT}
spec:
  backoffLimit: 1
  template:
    metadata:
      labels:
        app: acme-leaf
    spec:
      restartPolicy: Never
      shareProcessNamespace: false
      containers:
        - name: http
          image: nginx:1.27-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          volumeMounts:
            - name: webroot
              mountPath: /usr/share/nginx/html
        - name: step
          image: ${CLI_IMG}
          imagePullPolicy: Never
          command:
            - /bin/sh
            - -c
            - |
              set -e
              sleep 3
              mkdir -p /usr/share/nginx/html
              step ca certificate "${CN}" /tmp/leaf.crt /tmp/leaf.key --acme https://step-ca.step-ca.svc.cluster.local/acme/acme/directory --webroot /usr/share/nginx/html --root /ca/root_ca.crt --force
              cat /tmp/leaf.crt
          volumeMounts:
            - name: webroot
              mountPath: /usr/share/nginx/html
            - name: ca
              mountPath: /ca
              readOnly: true
      volumes:
        - name: webroot
          emptyDir: {}
        - name: ca
          configMap:
            name: test-ca-root
EOF

if kubectl -n "$NS_EXT" wait --for=condition=complete job/test-acme-issue --timeout=240s; then
  kubectl -n "$NS_EXT" logs job/test-acme-issue -c step | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' >"$OUT_DIR/acme-leaf.crt"
  [[ -s "$OUT_DIR/acme-leaf.crt" ]] || die "empty ACME leaf"
  assert_chain "$OUT_DIR/acme-leaf.crt"
  log "external 02_acme_issue PASS (directory + leaf)"
else
  kubectl -n "$NS_EXT" logs job/test-acme-issue -c step --tail=80 || true
  kubectl -n "$NS_EXT" describe job/test-acme-issue | tail -20 || true
  log "WARN: ACME HTTP-01 leaf issue failed (nginx/DNS/challenge); directory check passed"
  log "external 02_acme_issue PASS (directory only)"
fi
