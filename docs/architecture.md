# Architecture

See [hld.md](hld.md) and root [README.md](../README.md).

## Trust chain

Root CA (offline, admin assume-role + Root KMS) → Intermediate CA (online step-ca + Intermediate KMS) → workload leaf certs.

## Local fidelity

LocalStack provides KMS/IAM/STS so local kind deploys exercise the same signing path as production.

## Workflows

Mermaid diagrams for bootstrap, issue/renew leaf, Intermediate renewal, Root rotation, revoke: [workflows/README.md](workflows/README.md).

## Leaf interface

Issue / renew / trust contract for workloads: [interfaces/leaf-service.md](interfaces/leaf-service.md).
