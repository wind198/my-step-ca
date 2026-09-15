# PKI workflows

Mermaid diagrams for common private-PKI operations. Runbooks under [`../runbooks/`](../runbooks/) carry step-by-step commands; these pages show control flow, **scripts**, and **APIs**.

| Shape | Meaning |
|-------|---------|
| `[[path]]` | Make target or repo script |
| `([METHOD path])` | HTTP or AWS API |
| `[Name]` | Actor, process, or artifact |

| Workflow | When | Diagram |
|----------|------|---------|
| Bootstrap | New environment / first CA | [bootstrap.md](bootstrap.md) |
| Issue leaf | Workload needs a certificate | [issue-leaf-certificate.md](issue-leaf-certificate.md) — contract: [../interfaces/leaf-service.md](../interfaces/leaf-service.md) |
| Renew leaf | Short-lived cert near expiry | [renew-leaf-certificate.md](renew-leaf-certificate.md) — contract: [../interfaces/leaf-service.md](../interfaces/leaf-service.md) |
| Renew Intermediate | Intermediate nearing expiry / key replace | [renew-intermediate-ca.md](renew-intermediate-ca.md) |
| Rotate Root | Planned or emergency Root change | [rotate-root-ca.md](rotate-root-ca.md) |
| Revoke | Compromised leaf or bad issuance | [revoke-certificate.md](revoke-certificate.md) |

## Rules of thumb

- Routine leaf issue/renew never touches Root or admin assume-role.
- Intermediate renewal requires offline Root signing on the admin machine.
- Root rotation is manual, with trust-anchor overlap before retirement.
