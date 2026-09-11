# Intermediate CA renewal

```text
Generate new Intermediate CSR (new KMS key or same key policy)
  → Offline Root signs CSR (admin assume-role)
  → Deploy new Intermediate certificate to step-ca
  → Validate chain
  → Roll online CA
  → Verify issuance
  → Rollback plan if issuance fails
```

Never depends on an online Root CA. Keep old Intermediate cert available until workloads migrate.

Diagram: [../workflows/renew-intermediate-ca.md](../workflows/renew-intermediate-ca.md)
