# 004 — K8SSA preferred for in-cluster leaves

## Context

Workloads need to authenticate to `step-ca` to get short-lived certs. Shared JWK/passwords in every pod are easy to leak. ACME fits some external clients. Kubernetes already issues ServiceAccount tokens.

## Decision

**Preferred in-cluster path:** Kubernetes Service Account (K8SSA) provisioner.

- `namespace` + `serviceAccount` → allowed SAN only
- No static provisioner passwords in leaf Deployments for production
- External / non-K8s: ACME or tightly scoped JWK/OIDC — see [interfaces/leaf-service.md](../interfaces/leaf-service.md)

## Alternatives

- ACME-first for all workloads — extra HTTP-01/DNS-01 plumbing inside the cluster
- Unrestricted JWK per service — fast to demo, weak identity binding

## Consequences

- K8SSA templates must not allow arbitrary SANs
- step-ca currently expects **legacy** SA tokens (`iss=kubernetes/serviceaccount`); bound tokens are rejected — tests mount a `kubernetes.io/service-account-token` Secret
- Leaf owners should not need Root/KMS/admin docs
