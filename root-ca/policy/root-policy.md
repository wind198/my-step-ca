# Root CA policy

- Offline / admin-only operations
- Signs Intermediate CAs only (not workload leaves)
- Root KMS key: `pki-admin` yes; `step-ca` role no
- Rotation: explicit runbook, never automatic
