# Certificate policy (stub)

| Profile | Max lifetime | Auth |
|---------|--------------|------|
| Root CA | years (org policy) | offline admin |
| Intermediate CA | years (shorter than Root) | Root-signed |
| Workload TLS | hours–days | K8SSA |
| Admin leaf | short | JWK/OIDC provisioner |

TODO: set `COMPANY_DOMAIN`, default TTLs, EKUs, name constraints.
