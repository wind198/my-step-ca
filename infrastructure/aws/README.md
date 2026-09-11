# AWS infrastructure (KMS + IAM)

Dedicated Terraform roots for **local** (LocalStack) and **prod** (real AWS). Shared modules under `modules/`.

```text
infrastructure/aws/
├── modules/           # shared KMS + IAM (no provider)
├── local/             # LocalStack — `make tf-apply-local`
└── prod/              # real AWS — manual apply only
```

## Modules

| Path | Purpose |
|------|---------|
| `modules/kms-root` | Root CA KMS key — admin only |
| `modules/kms-intermediate` | Intermediate CA KMS — admin + step-ca Sign/GetPublicKey |
| `modules/iam-admin` | `pki-admin` role (`assume_role_policy` injected by env) |
| `modules/iam-step-ca` | `step-ca` role (`assume_role_policy` injected by env) |

## Local (LocalStack)

```bash
make localstack-up
make tf-apply-local
```

Trust: account root may assume both roles (admin-machine smoke tests).

## Production

1. Copy `prod/terraform.tfvars.example` → `prod/terraform.tfvars` (gitignored pattern via `*.tfvars` except examples — use a local untracked file).
2. Copy `prod/backend.tf.example` → `prod/backend.tf` when remote state is ready.
3. Fill `REPLACE_ME` / `AWS_ACCOUNT_ID` placeholders.
4. `cd infrastructure/aws/prod && terraform init && terraform plan` — apply only with explicit change control.

Prod trust:

- `pki-admin`: `admin_principal_arns` (SSO / break-glass)
- `step-ca`: IRSA via `oidc_provider_arn` + namespace/SA

Never `terraform apply` prod from PR CI or a ambiguous Make target.
