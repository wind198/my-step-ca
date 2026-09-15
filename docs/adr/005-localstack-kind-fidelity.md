# 005 — LocalStack + kind as prod-shaped local path

## Context

Maintainers need to exercise KMS signing, IAM roles, and Helm without a real AWS account. A software CA on the laptop would be faster but would not hit the same signing path as production.

## Decision

- **Local:** LocalStack (KMS/IAM/STS) + kind. Same scripts and Helm chart as prod; identity plumbing differs (assumed-role Secret vs IRSA).
- **Prod:** real AWS, IRSA/Pod Identity, Terraform under `infrastructure/aws/prod/` applied only with change control.
- **No** `make deploy` (or other ambiguous target) that can hit production.

LocalStack is **not** a production trust boundary.

## Alternatives

- Mock CA / file-backed keys locally — faster, diverges from prod KMS
- Shared sandbox AWS account for every laptop — more real, slower and costlier for onboarding

## Consequences

- Local debugging includes kind DNS/image load, cap-drop EPERM, and pod→LocalStack networking
- Prod apply stays a documented, explicit operator action ([deployment.md](../deployment.md))
- `make lint validate` is the current CI gate; no GitHub Actions yet
