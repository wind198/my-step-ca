# Workflow: Renew Intermediate CA

Admin-machine operation. New Intermediate material (often new KMS key + CSR); offline Root signs; online CA rolls to the new cert. Never depends on an online Root.

Runbook: [../runbooks/intermediate-renewal.md](../runbooks/intermediate-renewal.md)

```mermaid
flowchart TD
  subgraph admin ["Admin machine"]
    assume[["make assume-admin / assume-role.sh"]]
    genInt[["root-ca/scripts/generate-intermediate-csr.sh"]]
    vfy[["root-ca/scripts/verify-chain.sh"]]
    vfyInt[["intermediate-ca/scripts/verify.sh"]]
  end

  subgraph awsApis ["AWS"]
    sts(["sts:AssumeRole pki-admin"])
    kmsRoot(["kms:Sign Root"])
    kmsInt(["kms:GetPublicKey Intermediate"])
  end

  subgraph k8s ["Online CA"]
    deploy[["scripts/localstack/deploy-kind.sh or helm upgrade"]]
    health(["GET /health"])
    signApi(["POST /1.0/sign smoke"])
    rollback[["helm rollback / prior intermediate_ca.crt"]]
  end

  assume --> sts --> genInt
  genInt --> kmsInt
  genInt --> kmsRoot --> vfy --> vfyInt --> deploy
  deploy --> health --> signApi
  signApi -.->|issuanceFail| rollback
```

```mermaid
sequenceDiagram
    participant Operator
    participant AssumeSh
    participant STS
    participant GenInt
    participant KMS
    participant VerifySh
    participant Deploy
    participant StepCa

    Operator->>AssumeSh: assume-role.sh admin
    AssumeSh->>STS: sts:AssumeRole pki-admin
    Operator->>GenInt: generate-intermediate-csr.sh
    GenInt->>KMS: kms:DescribeKey Intermediate
    GenInt->>KMS: kms:Sign with Root key
    Note over GenInt: step certificate create profile intermediate-ca
    Operator->>VerifySh: verify-chain.sh
    Operator->>Deploy: helm upgrade plus new intermediate_ca.crt
    Deploy->>StepCa: GET /health
    Deploy->>StepCa: POST /1.0/sign smoke leaf
    alt Issuance fails
        Operator->>Deploy: helm rollback prior cert
    end
```

| Step | Script | APIs |
|------|--------|------|
| Identity | `scripts/localstack/assume-role.sh` (`make assume-admin`) | `sts:AssumeRole` (`pki-admin`) |
| New Intermediate | `root-ca/scripts/generate-intermediate-csr.sh` | `kms:DescribeKey`, `kms:GetPublicKey`, `kms:Sign` (Root) |
| Chain check | `root-ca/scripts/verify-chain.sh`, `intermediate-ca/scripts/verify.sh` | OpenSSL `verify -CAfile` |
| Roll online CA | `scripts/localstack/deploy-kind.sh` or Helm | Kubernetes apply |
| Prove issuance | `intermediate-ca/scripts/healthcheck.sh`, `step ca certificate` | `GET /health`, `POST /1.0/sign` → Intermediate `kms:Sign` |

`root-ca/scripts/sign-intermediate.sh` is a stub pointer at this runbook; do not use it as the signing path.

Keep the prior Intermediate certificate available until issuance is proven healthy.
