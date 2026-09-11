# Threat model (stub)

## Assets

- Root CA private key (Root KMS)
- Intermediate CA private key (Intermediate KMS)
- Provisioner credentials
- Issued workload certificates / identities

## Key threats

- Compromise of `step-ca` IAM role → Intermediate signing only (not Root)
- Compromised admin credentials → Root + Intermediate; mitigate with MFA, short sessions, CODEOWNERS
- Unrestricted K8SSA → arbitrary SANs; mitigate with explicit SA→SAN policy
- Secrets in Git; mitigate with `.gitignore`, gitleaks, no key PEMs in Secrets when KMS-backed

TODO: org-specific assets, attackers, residual risk acceptance.
