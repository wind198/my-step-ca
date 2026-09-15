# Workflow: Revoke certificate

Contain compromised or wrongly issued leaves (or disable a bad provisioner). Exact CRL/OCSP distribution is org-specific — treat those nodes as TODO until product choice is fixed.

Related: [../runbooks/incident-response.md](../runbooks/incident-response.md)

Operator action (not a leaf self-service). After revoke, re-issue via [issue-leaf-certificate.md](issue-leaf-certificate.md).

```mermaid
flowchart TD
  detect[Detect compromise or bad issue]

  subgraph contain ["Contain"]
    disableProv["Disable provisioner in ca.json"]
    helmRoll[["helm upgrade / rollout restart"]]
  end

  subgraph revokePath ["Revoke"]
    stepRevoke[["step ca revoke"]]
    revokeApi(["POST /1.0/revoke"])
  end

  subgraph distribute ["Distribution TODO"]
    crl["Publish CRL or OCSP"]
  end

  subgraph reissuePath ["Re-issue if needed"]
    signApi(["POST /1.0/sign"])
    kmsSign(["kms:Sign"])
  end

  post[Post-incident review]

  detect --> disableProv --> helmRoll
  detect --> stepRevoke --> revokeApi
  revokeApi --> crl
  crl --> signApi --> kmsSign --> post
```

```mermaid
sequenceDiagram
    participant Operator
    participant StepCli
    participant StepCa
    participant Helm
    participant Workload

    Operator->>StepCli: step ca revoke serial
    StepCli->>StepCa: POST /1.0/revoke
    StepCa-->>StepCli: revoked
    alt Bad provisioner
        Operator->>Helm: edit ca.json plus helm upgrade
        Helm->>StepCa: rollout new provisioners
    end
    Note over StepCa: CRL / OCSP publish is TODO
    Operator->>Workload: re-issue via POST /1.0/sign
```

| Action | Script / command | APIs |
|--------|------------------|------|
| Revoke leaf | `step ca revoke` | `POST /1.0/revoke` |
| Disable issuance | edit `local/config/ca.json` or ConfigMap; `helm upgrade` / `scripts/localstack/deploy-kind.sh` | Kubernetes apply; CA reload |
| Confirm CA up | `intermediate-ca/scripts/healthcheck.sh` | `GET /health` |
| Re-issue | `step ca certificate` | `POST /1.0/sign` → `kms:Sign` |
| CRL / OCSP | none in-repo | TODO |

If Intermediate or Root is compromised, escalate to [renew-intermediate-ca.md](renew-intermediate-ca.md) or [rotate-root-ca.md](rotate-root-ca.md) — leaf revoke alone is insufficient.
