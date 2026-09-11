# Disaster recovery

## Root CA

Depends on Root KMS key durability + admin role recovery + Root certificate backup + authorized operators. Root is never recovered by redeploying Kubernetes.

## Intermediate CA

- Intermediate KMS key durability
- Reproducible Helm deploy
- Intermediate certificate + chain
- `step-ca` DB/state (document persistence volume)
- Provisioner config

Redeploying the container alone is insufficient if DB/provisioner state is lost.

See runbooks: `ca-recovery.md`, `intermediate-renewal.md`, `root-rotation.md`.
