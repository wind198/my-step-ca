# Workflow: Rotate Root CA

Manual security operation — not automated. Publish new trust anchor with overlap; create and deploy a new Intermediate under the new Root; retire old Root only after the required trust period.

Runbook: [../runbooks/root-rotation.md](../runbooks/root-rotation.md)

```mermaid
flowchart TD
  newRoot[GenerateNewRootKms]
  publishTrust[PublishNewTrustAnchor]
  newInt[CreateNewIntermediate]
  signInt[NewRootSignsIntermediate]
  deployInt[DeployNewIntermediate]
  overlap[SupportTrustOverlap]
  migrate[MigrateWorkloads]
  retire[RetireOldRootAfterPeriod]
  newRoot --> publishTrust --> newInt --> signInt --> deployInt --> overlap --> migrate --> retire
```

Do not reuse a compromised Root KMS key.
