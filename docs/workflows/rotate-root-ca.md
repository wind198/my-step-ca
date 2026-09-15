# Workflow: Rotate Root CA

Manual security operation — not automated. Publish new trust anchor with overlap; create and deploy a new Intermediate under the new Root; retire old Root only after the required trust period.

Runbook: [../runbooks/root-rotation.md](../runbooks/root-rotation.md)

```mermaid
flowchart TD
  subgraph admin ["Admin machine"]
    tfNew["Terraform new Root KMS key"]
    assume[["assume-role.sh pki-admin"]]
    initRoot[["root-ca/scripts/init-root.sh"]]
    genInt[["root-ca/scripts/generate-intermediate-csr.sh"]]
    vfy[["root-ca/scripts/verify-chain.sh"]]
    publish[Distribute new root_ca.crt]
  end

  subgraph awsApis ["AWS"]
    createKey(["kms:CreateKey new Root"])
    sts(["sts:AssumeRole pki-admin"])
    kmsNewRoot(["kms:Sign new Root"])
    retireKms(["kms:ScheduleKeyDeletion after overlap"])
  end

  subgraph online ["Workloads plus step-ca"]
    deploy[["helm upgrade new Intermediate"]]
    roots(["GET /roots.pem overlap"])
    migrate[Migrate trust stores]
    signApi(["POST /1.0/sign under new Intermediate"])
  end

  tfNew --> createKey --> assume --> sts --> initRoot --> kmsNewRoot
  initRoot --> publish --> genInt --> kmsNewRoot
  genInt --> vfy --> deploy --> roots --> migrate --> signApi
  migrate -.-> retireKms
```

```mermaid
sequenceDiagram
    participant Operator
    participant Terraform
    participant AssumeSh
    participant InitRoot
    participant GenInt
    participant KMS
    participant Workloads
    participant StepCa

    Operator->>Terraform: new Root KMS key
    Terraform->>KMS: kms:CreateKey
    Operator->>AssumeSh: assume-role.sh admin
    AssumeSh->>KMS: sts then kms:DescribeKey
    Operator->>InitRoot: init-root.sh
    InitRoot->>KMS: kms:Sign new Root cert
    Note over InitRoot: step certificate create profile root-ca
    Operator->>Workloads: publish new root_ca.crt overlap
    Workloads->>StepCa: GET /roots.pem
    Operator->>GenInt: generate-intermediate-csr.sh
    GenInt->>KMS: kms:Sign Intermediate with new Root
    Operator->>StepCa: helm upgrade new Intermediate
    StepCa->>KMS: kms:Sign leafs with new Intermediate
    Note over Operator: retire old Root only after trust period
    Operator->>KMS: kms:ScheduleKeyDeletion
```

| Step | Script | APIs |
|------|--------|------|
| New Root key | Terraform (`infrastructure/aws`) | `kms:CreateKey`, `kms:CreateAlias` |
| Identity | `scripts/localstack/assume-role.sh` | `sts:AssumeRole` (`pki-admin`) |
| New Root cert | `root-ca/scripts/init-root.sh` | `kms:DescribeKey`, `kms:GetPublicKey`, `kms:Sign` |
| Trust overlap | distribute `root_ca.crt`; workloads may `curl` | `GET /roots.pem` |
| New Intermediate | `root-ca/scripts/generate-intermediate-csr.sh` | Root `kms:Sign` |
| Deploy | Helm / `scripts/localstack/deploy-kind.sh` | `GET /health`, `POST /1.0/sign` |
| Retire old Root | after overlap | `kms:ScheduleKeyDeletion` |

Do not reuse a compromised Root KMS key. `pki-admin` signs Root; the `step-ca` role never gets Root KMS.
