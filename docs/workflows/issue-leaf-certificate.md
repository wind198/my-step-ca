# Workflow: Issue leaf certificate

Online path only. Workload authenticates to `step-ca` (K8SSA or ACME); Intermediate private key signs via KMS. Root stays offline.

Related: [../certificate-policy.md](../certificate-policy.md), provisioner notes under `intermediate-ca/provisioners/`.

Preferred path (K8SSA). Client: `step ca certificate --provisioner kube-default` (or any Smallstep HTTP client). Tests: `test/k8ssa/02_issue_allowed_san.sh`, deny: `test/k8ssa/03_deny_arbitrary_san.sh`.

```mermaid
flowchart LR
  subgraph client ["Workload"]
    pod[Pod plus SA]
    stepCli[["step ca certificate --provisioner kube-default"]]
  end

  subgraph stepCa ["step-ca"]
    health(["GET /health"])
    roots(["GET /roots.pem"])
    signApi(["POST /1.0/sign"])
    k8ssa[provisioner kube-default]
    tmpl[["k8ssa-workload.json"]]
  end

  subgraph kmsLane ["Intermediate KMS"]
    kmsSign(["kms:Sign"])
    kmsPub(["kms:GetPublicKey"])
  end

  leaf[Leaf plus Intermediate chain]

  pod -->|"legacy SA JWT"| stepCli
  stepCli --> health
  stepCli --> roots
  stepCli -->|"OTT plus CSR"| signApi --> k8ssa --> tmpl
  signApi --> kmsSign
  kmsSign --> kmsPub
  kmsSign --> leaf
```

```mermaid
sequenceDiagram
    participant Workload
    participant StepCli
    participant StepCa
    participant Provisioner
    participant Template
    participant KMS

    Workload->>StepCli: SA token plus CN
    StepCli->>StepCa: GET /health
    StepCli->>StepCa: GET /roots.pem
    StepCli->>StepCa: POST /1.0/sign
    StepCa->>Provisioner: K8SSA kube-default
    Provisioner->>Template: k8ssa-workload.json SAN from SA
    alt SAN allowed
        StepCa->>KMS: kms:Sign
        KMS-->>StepCa: signature
        StepCa-->>StepCli: 201 leaf plus chain
    else SAN not allow-listed
        StepCa-->>StepCli: policy denial
    end
    Note over StepCli: Unauthenticated POST /1.0/sign must not be 200
    Note over StepCli: test/external/04_deny_without_auth.sh
```

Optional ACME (cert-manager or `step ca certificate --acme`). ClusterIssuer: `integrations/cert-manager/clusterissuer.yaml`. Test: `test/external/02_acme_issue.sh`.

```mermaid
sequenceDiagram
    participant Client
    participant StepCa
    participant Solver
    participant KMS

    Client->>StepCa: GET /acme/acme/directory
    StepCa-->>Client: newNonce newAccount newOrder
    Client->>StepCa: ACME newAccount plus newOrder
    StepCa->>Solver: HTTP-01 challenge
    Solver-->>StepCa: key authorization
    Client->>StepCa: ACME finalize CSR
    StepCa->>KMS: kms:Sign
    KMS-->>StepCa: signature
    StepCa-->>Client: leaf plus chain
```

| Client | Script / test | APIs |
|--------|---------------|------|
| K8SSA workload | `step ca certificate --provisioner kube-default --k8ssa-token-path …` | `GET /health`, `GET /roots.pem`, `POST /1.0/sign` → `kms:Sign` |
| ACME / cert-manager | `step ca certificate --acme …/acme/acme/directory` | `GET /acme/acme/directory`, ACME newNonce / newAccount / newOrder / finalize → `kms:Sign` |
| External JWK (dev) | `test/external/03_jwk_issue_and_renew.sh` | `POST /1.0/sign` with JWK provisioner `external-test` |
| Health / trust | `intermediate-ca/scripts/healthcheck.sh`, `test/k8ssa/01_health_and_roots.sh` | `GET /health`, `GET /roots.pem` |

In-cluster base URL: `https://step-ca.step-ca.svc.cluster.local` (Service `:443` → CA `:9000`).

Do not allow unrestricted SA → arbitrary SAN mappings.

Interface contract: [../interfaces/leaf-service.md](../interfaces/leaf-service.md).
