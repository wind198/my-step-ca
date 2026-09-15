# Workflow: Bootstrap PKI

First-time (or rebuilt) environment: create KMS/IAM, offline Root, Intermediate, deploy online `step-ca`, verify.

Runbook: [../runbooks/bootstrap.md](../runbooks/bootstrap.md)

Local path is fully scripted (`Makefile`). Production uses the same Root scripts + Terraform/Helm, not a `make deploy` target.

```mermaid
flowchart TD
  subgraph makeTargets ["Make"]
    lsUp[["make localstack-up"]]
    tfApply[["make tf-apply-local"]]
    assumeAdmin[["make assume-admin"]]
    bootLocal[["make bootstrap-local"]]
    deployDev[["make deploy-dev"]]
    verifyMake[["make verify-chain"]]
  end

  subgraph scripts ["Scripts"]
    waitSh[["scripts/localstack/wait.sh"]]
    exportSh[["scripts/localstack/export-outputs.sh"]]
    assumeSh[["scripts/localstack/assume-role.sh"]]
    bootSh[["scripts/localstack/bootstrap.sh"]]
    initRoot[["root-ca/scripts/init-root.sh"]]
    genInt[["root-ca/scripts/generate-intermediate-csr.sh"]]
    vfyRoot[["root-ca/scripts/verify-chain.sh"]]
    deployKind[["scripts/localstack/deploy-kind.sh"]]
  end

  subgraph awsApis ["AWS / LocalStack"]
    lsHealth(["GET /_localstack/health"])
    tfKms["terraform apply KMS plus IAM"]
    stsAdmin(["sts:AssumeRole pki-admin"])
    kmsRoot(["kms:DescribeKey GetPublicKey Sign"])
    stsCa(["sts:AssumeRole step-ca"])
  end

  subgraph k8s ["Kubernetes"]
    helmUp[["helm upgrade --install step-ca"]]
    health(["GET /health"])
    roots(["GET /roots.pem"])
  end

  lsUp --> waitSh --> lsHealth
  tfApply --> tfKms --> exportSh
  assumeAdmin --> assumeSh --> stsAdmin
  bootLocal --> bootSh --> initRoot --> kmsRoot
  bootSh --> genInt --> kmsRoot
  genInt --> vfyRoot
  deployDev --> deployKind --> stsCa
  deployKind --> helmUp --> health
  verifyMake --> vfyRoot
  health -.-> roots
```

```mermaid
sequenceDiagram
    participant Make
    participant WaitSh
    participant Terraform
    participant AssumeSh
    participant BootSh
    participant InitRoot
    participant GenInt
    participant VerifySh
    participant DeployKind
    participant LocalStack
    participant STS
    participant KMS
    participant Helm
    participant StepCa

    Make->>WaitSh: make localstack-up
    WaitSh->>LocalStack: GET /_localstack/health
    Make->>Terraform: make tf-apply-local
    Terraform->>KMS: CreateKey Root and Intermediate
    Make->>AssumeSh: make assume-admin
    AssumeSh->>STS: sts:AssumeRole pki-admin
    Make->>BootSh: make bootstrap-local
    BootSh->>InitRoot: init-root.sh
    InitRoot->>KMS: kms:DescribeKey
    InitRoot->>KMS: kms:GetPublicKey plus kms:Sign
    Note over InitRoot: step certificate create profile root-ca
    BootSh->>GenInt: generate-intermediate-csr.sh
    GenInt->>KMS: kms:Sign Root over Intermediate
    Note over GenInt: step certificate create profile intermediate-ca
    BootSh->>VerifySh: verify-chain.sh
    Note over BootSh: step ca provisioner add ACME JWK K8SSA
    Make->>DeployKind: make deploy-dev
    DeployKind->>STS: sts:AssumeRole step-ca
    DeployKind->>Helm: helm upgrade install
    DeployKind->>StepCa: GET /health
```

| Make | Script | APIs |
|------|--------|------|
| `localstack-up` | `scripts/localstack/wait.sh` | `GET /_localstack/health` |
| `tf-apply-local` | `scripts/localstack/export-outputs.sh` | Terraform → `kms:CreateKey`, IAM roles |
| `assume-admin` | `scripts/localstack/assume-role.sh` | `sts:AssumeRole` (`pki-admin`) |
| `bootstrap-local` | `scripts/localstack/bootstrap.sh` → `init-root.sh`, `generate-intermediate-csr.sh`, `verify-chain.sh` | `kms:DescribeKey`, `kms:GetPublicKey`, `kms:Sign` |
| `deploy-dev` | `scripts/localstack/deploy-kind.sh` | `sts:AssumeRole` (`step-ca`), Helm, `GET /health` |
| `verify-chain` | `scripts/verify-chain.sh` → `root-ca/scripts/verify-chain.sh` | local OpenSSL chain check |

`root-ca/scripts/sign-intermediate.sh` is a stub; signing is `generate-intermediate-csr.sh`.

Root CA stays on the admin path only — never a Kubernetes Deployment.
