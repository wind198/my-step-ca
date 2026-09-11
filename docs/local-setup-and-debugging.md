# Local setup notes (kind + LocalStack KMS)

How this repo was brought up on an admin laptop against `kind-kind`, and what broke along the way.

## Target shape

```text
Admin machine
  → AWS CLI (LocalStack test creds)
  → sts:AssumeRole → pki-admin
  → Root + Intermediate certs (keys in LocalStack KMS)

kind pods (step-ca)
  → assumed step-ca role creds (K8s Secret, local only)
  → AWS_ENDPOINT_URL → host bridge → LocalStack :4566
  → kms:Sign / GetPublicKey on Intermediate key only
```

Prod differs only in identity plumbing (SSO + IRSA) and real AWS endpoints — same scripts and Helm chart.

## Quick path

Terraform for LocalStack lives under `infrastructure/aws/local/` (shared modules in `infrastructure/aws/modules/`). Prod is a separate root — never applied by Make.

```bash
# deps: docker, kubectl, helm, terraform, aws, jq, openssl
# step CLI + step-kms-plugin on PATH (see below)

make localstack-up
make tf-apply-local
make assume-admin
make bootstrap-local   # or run root-ca scripts after sourcing local/.aws-session
make deploy-dev
```

Artifacts land in gitignored `local/` (certs, `ca.json`, `.aws-session`, terraform outputs).

### step CLI install (no sudo)

```bash
# step
curl -fsSL -o /tmp/step.tar.gz \
  "$(curl -fsSL https://api.github.com/repos/smallstep/cli/releases/latest \
    | jq -r '.assets[] | select(.name|test("linux_amd64.tar.gz$")) | .browser_download_url')"
tar -xzf /tmp/step.tar.gz -C /tmp
cp /tmp/step_*/bin/step ~/.local/bin/step

# kms plugin → ~/.step/plugins/
curl -fsSL -o /tmp/kms.tar.gz \
  "$(curl -fsSL https://api.github.com/repos/smallstep/step-kms-plugin/releases/latest \
    | jq -r '.assets[] | select(.name|test("linux_amd64.tar.gz$")) | .browser_download_url')"
tar -xzf /tmp/kms.tar.gz -C /tmp
mkdir -p ~/.step/plugins
cp "$(find /tmp -name step-kms-plugin -type f | head -1)" ~/.step/plugins/
export PATH="$HOME/.local/bin:$PATH"
export AWS_ENDPOINT_URL=http://localhost:4566   # required for LocalStack KMS
```

Root / Intermediate creation uses Smallstep’s KMS pattern (`--kms awskms:region=…` + `--key awskms:key-id=…`). With `AWS_ENDPOINT_URL` set, the AWS SDK talks to LocalStack.

## Kind networking to LocalStack

Pods cannot use `localhost:4566`. Deploy script sets:

```text
AWS_ENDPOINT_URL=http://<docker-bridge-gateway>:4566
# typically http://172.17.0.1:4566
```

LocalStack compose publishes `4566:4566` on the host. Confirm from a debug pod if needed:

```bash
kubectl -n step-ca run netcheck --rm -it --image=curlimages/curl --restart=Never -- \
  curl -sS http://172.17.0.1:4566/_localstack/health
```

## Debug log — failures and fixes

### 1. kind cannot pull from Docker Hub

**Symptom:** `ImagePullBackOff` / DNS timeout:

```text
lookup registry-1.docker.io on 172.20.0.1:53: i/o timeout
```

**Cause:** kind node DNS to the public registry flaky or blocked.

**Fix:** pull on the host, build a **single-arch** image, import with `ctr` (see `scripts/localstack/deploy-kind.sh`):

```bash
docker pull --platform linux/amd64 smallstep/step-ca:0.28.3
printf 'FROM smallstep/step-ca:0.28.3\n' | docker build --platform linux/amd64 -t smallstep/step-ca:kind -
docker save smallstep/step-ca:kind -o /tmp/step-ca-kind.tar
docker cp /tmp/step-ca-kind.tar kind-control-plane:/step-ca-kind.tar
docker exec kind-control-plane ctr -n k8s.io images import /step-ca-kind.tar
```

`values-dev.yaml` uses `image.tag: kind` and `pullPolicy: Never`.

**Also:** plain `kind load docker-image` failed here with:

```text
ctr: content digest sha256:…: not found
```

Manual `ctr images import` of the saved tar worked.

### 2. Multi-arch OCI index → broken runtime image

**Symptom:** image “present” but `exec /usr/local/bin/step-ca: operation not permitted`.

**Cause:** importing the multi-platform index left containerd with an incomplete/wrong platform bind.

**Fix:** import only `linux/amd64` (Dockerfile `FROM` + `docker build --platform linux/amd64` as above). Confirm:

```bash
docker exec kind-control-plane ctr -n k8s.io images ls | grep step-ca
# expect: linux/amd64 only for :kind
```

### 3. `capabilities.drop: ALL` → EPERM

**Symptom:** after image was correct, still:

```text
exec /usr/local/bin/step-ca: operation not permitted
```

**Cause:** container `securityContext.capabilities.drop: ["ALL"]` under this kind/containerd combo.

**Proof:** debug pod **without** cap drop ran `step-ca --help` fine; deploy with drop ALL crashed immediately.

**Fix:** do **not** set `capabilities.drop` in base/`values-dev`. Keep drop ALL only in `values-staging.yaml` / `values-prod.yaml`.

### 4. Helm value merge kept `drop: ALL`

**Symptom:** `values-dev` set `capabilities: {}` but live Deployment still had `drop: ["ALL"]`.

**Cause:** Helm deep-merges maps; empty `capabilities: {}` does not clear `drop` from `values.yaml`.

**Fix:** remove `capabilities` from base `values.yaml`; add drop ALL only in staging/prod overlays.

Verify:

```bash
kubectl -n step-ca get deploy step-ca \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext}' | jq .
# local: no capabilities.drop
```

### 5. Entrypoint + strict seccomp (related)

**Symptom:** `/entrypoint.sh: line 89: … Operation not permitted`.

**Mitigations used for kind:**

- `command: ["/usr/local/bin/step-ca"]` (bypass entrypoint)
- `seccompProfile.type: Unconfined` in `values-dev`
- `readOnlyRootFilesystem: false` in `values-dev`

Staging/prod keep stricter settings.

### 6. Health check via Service port-forward

**Symptom:** `curl https://127.0.0.1:9000/health` → `SSL routines::wrong version number` when forwarding `svc/step-ca 9000:443`.

**Fix:** port-forward the **pod** container port:

```bash
POD=$(kubectl -n step-ca get pod -l app.kubernetes.io/name=step-ca -o jsonpath='{.items[0].metadata.name}')
kubectl -n step-ca port-forward "pod/$POD" 19000:9000
curl -fsSk https://127.0.0.1:19000/health
# {"status":"ok"}
```

In-cluster kube-probes already succeeded (`GET /health` → 200) before external PF was fixed.

### 7. Helm `values.yaml` YAML typo

**Symptom:** `cannot unmarshal yaml … mapping values are not allowed`.

**Cause:** invalid nesting under a scalar `fullname:` key.

**Fix:** use `global.organization` / `global.domain` (see `values.yaml`).

## Sanity checks

```bash
# LocalStack
curl -fsS http://localhost:4566/_localstack/health

# Chain (admin machine)
make verify-chain
# or: openssl verify -CAfile local/certs/root_ca.crt local/certs/intermediate_ca.crt

# CA
kubectl -n step-ca get pods
kubectl -n step-ca logs -l app.kubernetes.io/name=step-ca --tail=50

# Chart
make helm-lint helm-template validate
```

## What must never be committed

- `local/**` (session creds, certs used in smoke tests, terraform output cache)
- Intermediate / Root **private key PEMs** (keys stay in KMS)
- Real AWS account IDs, production role ARNs, passwords

`.gitignore` already covers `local/**`, `*.key`, `*.pem`, credential filenames.

## Related docs

- [Architecture](architecture.md)
- [Bootstrap runbook](runbooks/bootstrap.md)
- Root README for make targets and trust model
