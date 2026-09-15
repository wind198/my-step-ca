# Docs

Project-level docs only. Module details live next to the code.

## Start here

- **Maintainer** — [development.md](development.md)
- **Operator** — [deployment.md](deployment.md)
- **Leaf / workload owner** — [interfaces/leaf-service.md](interfaces/leaf-service.md)

## System

- [architecture.md](architecture.md) — components and trust chain
- [adr/](adr/) — why those choices
- [certificate-policy.md](certificate-policy.md)
- [threat-model.md](threat-model.md)

## Build

- [development.md](development.md) — local setup, commands, tests
- [conventions.md](conventions.md) — naming, folders, docs rules

## Run

- [deployment.md](deployment.md) — environments, hosting, CI, monitoring
- [runbooks/](runbooks/) — bootstrap, renewal, rotation, recovery, incident
- [workflows/](workflows/) — control-flow diagrams
- [disaster-recovery.md](disaster-recovery.md)

## Module docs

- [root-ca/README.md](../root-ca/README.md) — offline Root scripts
- [intermediate-ca/README.md](../intermediate-ca/README.md) — provisioners and `ca.json`
- [infrastructure/aws/README.md](../infrastructure/aws/README.md) — Terraform KMS/IAM
- [test/README.md](../test/README.md) — K8SSA + external leaf tests
- [deploy/environments/dev/README.md](../deploy/environments/dev/README.md)
- [integrations/external-workloads/README.md](../integrations/external-workloads/README.md)
