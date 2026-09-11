# Interfaces

Contracts for consumers of this private PKI.

| Audience | Doc |
|----------|-----|
| Leaf / workload owners (issue, renew, trust) | [leaf-service.md](leaf-service.md) |
| PKI / platform operators | [../runbooks/](../runbooks/), [../workflows/](../workflows/) |

Leaf services talk only to the **online Intermediate** (`step-ca`). Root CA and KMS admin paths are out of scope for leaves.
