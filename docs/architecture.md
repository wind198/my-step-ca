# Architecture

Offline Root signs an Intermediate. Online `step-ca` issues short-lived leaf certs. Root private key never enters the cluster.

```text
Admin machine (offline / break-glass)
  aws login → sts:AssumeRole → pki-admin → Root KMS
                    │
                    │ signs Intermediate
                    ▼
              Kubernetes
  Intermediate KMS ──kms:Sign──► step-ca (2+ replicas)
                                        │
                                        ▼
                               Workloads (K8SSA)
```

Why: [adr/](adr/). How ops flow: [workflows/](workflows/).

## Trust chain

| | Root CA | Intermediate CA |
|---|---|---|
| Where | Admin machine only | Kubernetes (`step-ca`) |
| Key | Root KMS (admin role only) | Intermediate KMS |
| Who signs | Admin via `pki-admin` | `step-ca` role: `kms:Sign`, `kms:GetPublicKey` |
| Online? | No — never a K8s Deployment | Yes |

Never grant `step-ca` access to the Root KMS key.

## Components

- [root-ca/](../root-ca/README.md) — offline Root lifecycle (not deployed)
- [intermediate-ca/](../intermediate-ca/README.md) — logical online CA config, provisioners, templates
- [infrastructure/aws/](../infrastructure/aws/README.md) — Terraform for KMS + IAM
- [deploy/helm/step-ca/](../deploy/helm/step-ca/) — online Intermediate chart
- [integrations/](../integrations/external-workloads/README.md) — cert-manager (optional), external workloads
- [test/](../test/README.md) — K8SSA + external leaf tests

## External services

- **AWS KMS / IAM / STS** — CA keys and roles. Local uses LocalStack (fidelity only, not a prod trust boundary).
- **Kubernetes** — runtime for `step-ca`. Staging/prod: IRSA or Pod Identity. Local: assumed-role creds in a Secret.
- **Workloads** talk only to the online Intermediate. Contract: [interfaces/leaf-service.md](interfaces/leaf-service.md).

## Deployment shape

- Helm chart, 2+ replicas.
- Staging/prod: real AWS + IRSA. Local: kind + LocalStack.
- Prod Terraform/Helm is never a casual Make target. Overview: [deployment.md](deployment.md).

## Policy and risk

- [certificate-policy.md](certificate-policy.md)
- [threat-model.md](threat-model.md)
- [disaster-recovery.md](disaster-recovery.md)
