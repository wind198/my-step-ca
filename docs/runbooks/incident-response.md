# Incident response (PKI)

1. Contain: revoke compromised provisioners / disable issuance if needed
2. Assess: Root vs Intermediate vs leaf compromise
3. Intermediate-only: rotate Intermediate key + renew; Root stays offline
4. Root compromise: emergency Root rotation + trust-anchor distribution
5. Communicate: security + platform owners (CODEOWNERS)
6. Post-incident: update threat model and IAM policies

Diagrams: [../workflows/revoke-certificate.md](../workflows/revoke-certificate.md), Intermediate [../workflows/renew-intermediate-ca.md](../workflows/renew-intermediate-ca.md), Root [../workflows/rotate-root-ca.md](../workflows/rotate-root-ca.md)
