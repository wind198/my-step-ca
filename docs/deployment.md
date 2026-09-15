# Deployment

Runtime and operator overview. Step-by-step commands live in [runbooks/](runbooks/). Maintainer local setup: [development.md](development.md).

## Environments

- **local / dev** — kind + LocalStack. [deploy/environments/dev/README.md](../deploy/environments/dev/README.md). Chart overlay: `deploy/helm/step-ca/values-dev.yaml`.
- **staging** — real AWS KMS + IRSA, no LocalStack. `values-staging.yaml`. [deploy/environments/staging/README.md](../deploy/environments/staging/README.md).
- **prod** — `values-prod.yaml`, explicit approval. **No** `make deploy`. [deploy/environments/prod/README.md](../deploy/environments/prod/README.md).

## Hosting

Online Intermediate is the Helm chart [deploy/helm/step-ca/](../deploy/helm/step-ca/) (`2+` replicas). Root CA is never deployed.

Infra: Terraform roots in [infrastructure/aws/local/](../infrastructure/aws/local/) (`make tf-apply-local`) vs [infrastructure/aws/prod/](../infrastructure/aws/prod/) (manual `terraform plan` / apply with change control). Details: [infrastructure/aws/README.md](../infrastructure/aws/README.md).

## Identity

```text
Admin:   aws login → sts:AssumeRole → pki-admin → Root KMS (+ Intermediate bootstrap)
Pods:    ServiceAccount → IRSA / Pod Identity (staging/prod)
         or assumed step-ca role Secret (LocalStack only) → Intermediate KMS
```

`step-ca` never gets the Root KMS key.

## CI

No GitHub Actions yet. Gate: `make lint validate` ([scripts/lint.sh](../scripts/lint.sh), [scripts/validate.sh](../scripts/validate.sh)).

Prod Terraform/Helm is not applied from PR CI.

## Monitoring

- `/health` (HTTPS on the CA port), Kubernetes liveness/readiness probes
- Optional Prometheus ServiceMonitor (`serviceMonitor.enabled` on the chart)
- Watch: CA availability, issuance/renewal failures, KMS auth and throttle errors, leaf + Intermediate + Root expiry

Do not expose admin endpoints publicly.

## Operations

- Bootstrap: [runbooks/bootstrap.md](runbooks/bootstrap.md) · [workflows/bootstrap.md](workflows/bootstrap.md)
- Intermediate renewal: [runbooks/intermediate-renewal.md](runbooks/intermediate-renewal.md)
- Root rotation: [runbooks/root-rotation.md](runbooks/root-rotation.md)
- CA recovery: [runbooks/ca-recovery.md](runbooks/ca-recovery.md)
- Incident: [runbooks/incident-response.md](runbooks/incident-response.md)
- DR: [disaster-recovery.md](disaster-recovery.md)
- All diagrams: [workflows/README.md](workflows/README.md)
