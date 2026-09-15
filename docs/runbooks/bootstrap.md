# Bootstrap runbook

## Prerequisites

- Admin machine with AWS CLI
- `step` CLI
- Local: LocalStack + kind; Prod: real AWS + EKS (or approved cluster)

## Identity

```text
aws login → sts:AssumeRole → pki-admin → KMS
```

Never use long-lived keys bound to Root operations outside assumed role sessions.

## Local (LocalStack + kind)

```bash
make localstack-up
make tf-apply-local
make assume-admin
make bootstrap-local
make deploy-dev
make verify-chain
```

## Production (outline)

1. Apply Terraform to real AWS (separate change control)
2. Assume `pki-admin` via SSO
3. Initialize Root (if new) / ensure Intermediate KMS key exists
4. Generate Intermediate CSR; Root signs
5. Deploy Helm with IRSA annotation + Intermediate KMS ARN
6. Configure K8SSA provisioner
7. Issue test certificate; verify chain and KMS Sign

Root CA is never deployed to Kubernetes.

Diagram: [../workflows/bootstrap.md](../workflows/bootstrap.md)

Local kind failures (image pull, EPERM, Helm merge, port-forward): see [development.md](../development.md).
