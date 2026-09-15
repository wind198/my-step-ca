# Workflow: Renew leaf certificate

Short-lived leaves renew without Root or Intermediate re-signing. Same provisioner auth as issue; swap cert on the workload.

Related: [issue-leaf-certificate.md](issue-leaf-certificate.md)

Two equivalent online paths (neither uses `pki-admin` or Root KMS):

1. **Re-issue** — `step ca certificate` again → `POST /1.0/sign` (what `test/k8ssa/04_renew_leaf.sh` and `test/external/03_jwk_issue_and_renew.sh` do).
2. **mTLS renew** — `step ca renew` → `POST /1.0/renew` with the current leaf.

```mermaid
flowchart TD
  subgraph trigger ["Trigger"]
    expiry[Expiry or renewBefore]
    cm[cert-manager Certificate]
  end

  subgraph clients ["Clients"]
    reissue[["step ca certificate --provisioner kube-default"]]
    mtls[["step ca renew leaf.crt leaf.key"]]
    acme[["ACME plus cert-manager"]]
  end

  subgraph stepCa ["step-ca"]
    signApi(["POST /1.0/sign"])
    renewApi(["POST /1.0/renew"])
    acmeDir(["GET /acme/acme/directory"])
    k8ssa[K8SSA or JWK policy]
  end

  subgraph kmsLane ["Intermediate KMS"]
    kmsSign(["kms:Sign"])
  end

  swap[Hot-swap TLS on workload]

  expiry --> reissue & mtls
  cm --> acme
  reissue --> signApi --> k8ssa --> kmsSign
  mtls --> renewApi --> kmsSign
  acme --> acmeDir --> kmsSign
  kmsSign --> swap
```

```mermaid
sequenceDiagram
    participant Workload
    participant StepCli
    participant StepCa
    participant KMS

    Workload->>StepCli: cert near expiry
    alt Re-issue as tests
        StepCli->>StepCa: POST /1.0/sign
        Note over StepCli: same SA JWT or JWK as issue
    else Native renew
        StepCli->>StepCa: POST /1.0/renew
        Note over StepCli: mTLS with current leaf
    end
    StepCa->>KMS: kms:Sign
    KMS-->>StepCa: signature
    StepCa-->>StepCli: new leaf plus chain
    StepCli->>Workload: reload or hot-swap
```

| Client | Script / test | APIs |
|--------|---------------|------|
| K8SSA re-issue | `test/k8ssa/04_renew_leaf.sh` → `step ca certificate --provisioner kube-default` | `POST /1.0/sign` → `kms:Sign` |
| JWK re-issue | `test/external/03_jwk_issue_and_renew.sh` | `POST /1.0/sign` |
| Native renew | `step ca renew` | `POST /1.0/renew` → `kms:Sign` |
| ACME | cert-manager or `step ca certificate --acme` | `GET /acme/acme/directory` + ACME order finalize |

TTL bounds (example `ca.json`): default leaf `1h`, K8SSA max `8h`, authority max `24h`. Do not request above provisioner `maxTLSCertDuration`.

No admin assume-role and no Root involvement for routine leaf renewal.

Interface contract: [../interfaces/leaf-service.md](../interfaces/leaf-service.md).
