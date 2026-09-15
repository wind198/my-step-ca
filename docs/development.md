# Development

Onboarding for people who **change this repo**. Operators: [deployment.md](deployment.md).

## Prerequisites

docker, kubectl, helm, terraform, aws CLI, jq, openssl, `step` CLI, `step-kms-plugin`.

`step` + plugin (no sudo):

```bash
# step → ~/.local/bin
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
export AWS_ENDPOINT_URL=http://localhost:4566   # LocalStack KMS
```

## Local path

Same chart and scripts as prod; LocalStack stands in for AWS.

```bash
make localstack-up
make tf-apply-local
make assume-admin
make bootstrap-local
make deploy-dev
```

Artifacts: gitignored `local/` (certs, `ca.json`, `.aws-session`, terraform outputs).

## Commands

```text
make lint helm-lint helm-template validate
make localstack-up localstack-down
make tf-apply-local assume-admin bootstrap-local
make deploy-dev undeploy-dev
make verify-chain
make test test-k8ssa test-external
```

No `make deploy` for production.

## Workflow

1. Change code or chart values
2. `make lint validate`
3. Local deploy (`deploy-dev` if the CA path changed)
4. `make test` — see [test/README.md](../test/README.md)

## Debug entry points

- **Kind cannot pull Docker Hub** — pull on the host, build single-arch `linux/amd64`, import with `ctr` (`scripts/localstack/deploy-kind.sh`). `values-dev.yaml` uses `image.tag: kind` and `pullPolicy: Never`.
- **`capabilities.drop: ALL` → EPERM** on kind — do not set cap drop in base/`values-dev`. Staging/prod overlays keep drop ALL.
- **Helm map merge** — empty `capabilities: {}` does not clear `drop` from a parent values file. Keep `capabilities` out of base `values.yaml`.
- **Health from the laptop** — port-forward the **pod** container port `:9000`, not Service `:443`. In-cluster probes already hit `/health`.
- **Pods → LocalStack** — `AWS_ENDPOINT_URL=http://<docker-bridge-gateway>:4566` (often `172.17.0.1`), never `localhost` from inside the cluster.

Sanity:

```bash
curl -fsS http://localhost:4566/_localstack/health
make verify-chain
kubectl -n step-ca get pods
kubectl -n step-ca logs -l app.kubernetes.io/name=step-ca --tail=50
```

## Deeper work

- Offline Root: [root-ca/README.md](../root-ca/README.md)
- Intermediate config: [intermediate-ca/README.md](../intermediate-ca/README.md)
- Terraform: [infrastructure/aws/README.md](../infrastructure/aws/README.md)
- Tests: [test/README.md](../test/README.md)
- Conventions: [conventions.md](conventions.md)
