# Company Private PKI

Production-oriented private PKI using `step-ca`, Kubernetes, AWS KMS, and offline Root CA administration.

## Architecture

```text
                    ADMIN MACHINE (offline / break-glass)

                       ┌──────────────────┐
                       │    Root CA       │
                       │  (KMS-backed)    │
                       │  admin assume-role
                       └────────┬─────────┘
                                │ signs Intermediate
                                ▼
                         ONLINE (Kubernetes)

                 ┌──────────────────────────┐
                 │  AWS KMS / LocalStack    │
                 │  Intermediate CA key     │
                 └────────────┬─────────────┘
                              │ kms:Sign
                              ▼
                 ┌──────────────────────────┐
                 │  step-ca (2+ replicas)   │
                 │  Intermediate CA         │
                 └────────────┬─────────────┘
                              │ issue short-lived certs
                              ▼
                         Workloads (K8SSA)
```

## Root vs Intermediate

| | Root CA | Intermediate CA |
|---|---|---|
| Where | Admin machine only | Kubernetes (`step-ca`) |
| Key | Root KMS key (admin role only) | Intermediate KMS key |
| Who signs | Admin via `sts:AssumeRole` → `pki-admin` | `step-ca` role: `kms:Sign`, `kms:GetPublicKey` |
| Online? | No — never a K8s Deployment | Yes |

## AWS identity model

**Admin (this laptop / break-glass host):**

```text
aws login → sts:AssumeRole → pki-admin → Root KMS (+ Intermediate bootstrap)
```

**Online CA pods:**

```text
ServiceAccount → IRSA/Pod Identity (prod) or assumed step-ca role (LocalStack) → Intermediate KMS only
```

Never grant `step-ca` access to the Root KMS key.

## Repository structure

- `root-ca/` — offline Root lifecycle (not deployed to Kubernetes)
- `intermediate-ca/` — logical online CA config (KMS key URI, provisioners, templates)
- `infrastructure/aws/` — Terraform for KMS + IAM (LocalStack or real AWS)
- `deploy/helm/step-ca/` — online Intermediate CA chart
- `integrations/cert-manager/` — optional
- `scripts/localstack/` — local prod-shaped KMS
- `local/` — gitignored bootstrap artifacts
- `docs/` — architecture, runbooks, workflows (Mermaid), leaf interfaces, HLD
- `test/` — K8SSA + external leaf workflow integration tests (`make test`)

## Bootstrap sequence (local = LocalStack)

1. `make localstack-up`
2. `make tf-apply-local` — create KMS keys + IAM roles
3. `make assume-admin` — session as `pki-admin`
4. `make bootstrap-local` — Root + Intermediate (keys in KMS)
5. `make deploy-dev` — Helm to kind
6. Smoke-test health / issuance

Prod: same scripts against real AWS; Intermediate signing uses IRSA, not static keys.

## Secret handling

- No private keys, passwords, or AWS credentials in Git
- Intermediate signing key is **not** a Kubernetes Secret when KMS-backed
- `local/` is gitignored

## Makefile targets

```text
make lint helm-lint helm-template validate
make localstack-up assume-admin bootstrap-local deploy-dev
make verify-chain
```

There is no ambiguous `make deploy` targeting production.

## Local kind + LocalStack notes

Setup path, kind/Docker Hub image load, `capabilities.drop` EPERM, Helm merge pitfalls, and health port-forward: [docs/local-setup-and-debugging.md](docs/local-setup-and-debugging.md).

## Disaster recovery

See [docs/disaster-recovery.md](docs/disaster-recovery.md) and runbooks under `docs/runbooks/`.

## Security assumptions

- Root private key never leaves Root KMS / never enters the cluster
- Least-privilege IAM: no `kms:*` / `Resource: "*"` in production policies
- K8SSA provisioner restricts namespace/SA → SAN mapping
- LocalStack is for local fidelity only — not a production trust boundary
