# Workflow: Bootstrap PKI

First-time (or rebuilt) environment: create KMS/IAM, offline Root, Intermediate, deploy online `step-ca`, verify.

Runbook: [../runbooks/bootstrap.md](../runbooks/bootstrap.md)

```mermaid
flowchart TD
  adminLogin[AdminAwsLogin]
  assumeAdmin[AssumeRolePkiAdmin]
  tfApply[ApplyKmsAndIam]
  initRoot[InitRootCaInKms]
  initInt[CreateIntermediateInKms]
  rootSign[RootSignsIntermediate]
  verifyChain[VerifyChain]
  helmDeploy[DeployStepCaHelm]
  smokeTest[IssueTestLeafAndHealth]
  adminLogin --> assumeAdmin --> tfApply
  tfApply --> initRoot --> initInt --> rootSign --> verifyChain
  verifyChain --> helmDeploy --> smokeTest
```

Root CA stays on the admin path only — never a Kubernetes Deployment.
