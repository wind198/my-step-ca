# Company Private PKI

Private PKI for short-lived workload certificates: offline Root CA (admin machine + AWS KMS), online Intermediate CA (`step-ca` on Kubernetes), keys in KMS.

## Quick start (local)

```bash
make localstack-up
make tf-apply-local
make assume-admin
make bootstrap-local
make deploy-dev
```

Prereqs, pitfalls, tests: [docs/development.md](docs/development.md).

## Who are you

- **Maintainer** (change this repo) → [docs/development.md](docs/development.md)
- **Operator** (run the CA) → [docs/deployment.md](docs/deployment.md)
- **Leaf / workload owner** → [docs/interfaces/leaf-service.md](docs/interfaces/leaf-service.md)

Full map: [docs/README.md](docs/README.md).

## Important links

- Architecture: [docs/architecture.md](docs/architecture.md)
- Conventions: [docs/conventions.md](docs/conventions.md)
- Offline Root: [root-ca/README.md](root-ca/README.md)
- Online Intermediate: [intermediate-ca/README.md](intermediate-ca/README.md)
- AWS KMS/IAM: [infrastructure/aws/README.md](infrastructure/aws/README.md)
- Tests: [test/README.md](test/README.md)
- Ownership: [CODEOWNERS](CODEOWNERS)
