# Offline Root CA

Admin-machine tooling only. **Never** deploy Root CA to Kubernetes.

## Identity

```bash
# LocalStack
make assume-admin

# Production
aws sso login --profile REPLACE_ME
aws sts assume-role --role-arn arn:aws:iam::AWS_ACCOUNT_ID:role/pki-admin --role-session-name pki-admin
```

## Scripts

| Script | Purpose |
|--------|---------|
| `init-root.sh` | Create Root CA cert using Root KMS key |
| `generate-intermediate-csr.sh` | CSR for Intermediate (key in Intermediate KMS) |
| `sign-intermediate.sh` | Root signs Intermediate CSR |
| `verify-chain.sh` | Validate Root → Intermediate |

All scripts use `set -euo pipefail` and require explicit `--output` / key ARNs.
