# Workflow: Renew Intermediate CA

Admin-machine operation. New Intermediate material (often new KMS key + CSR); offline Root signs; online CA rolls to the new cert. Never depends on an online Root.

Runbook: [../runbooks/intermediate-renewal.md](../runbooks/intermediate-renewal.md)

```mermaid
flowchart TD
  admin[AdminAssumeRole]
  csr[NewIntermediateCsrOrKey]
  rootSign[OfflineRootSigns]
  deploy[DeployIntermediateCert]
  validate[ValidateChain]
  roll[RollOnlineStepCa]
  verify[VerifyIssuance]
  rollback[RollbackPriorCert]
  admin --> csr --> rootSign --> deploy --> validate --> roll --> verify
  verify -.->|issuanceFail| rollback
```

Keep the prior Intermediate certificate available until issuance is proven healthy.
