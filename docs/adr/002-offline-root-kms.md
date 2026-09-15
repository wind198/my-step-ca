# 002 — Offline Root via admin assume-role + Root KMS

## Context

The Root private key must not be reachable from workloads or from the online CA. Options include an air-gapped HSM, a truly offline laptop with a local key, or a KMS key usable only by a break-glass admin role.

## Decision

Root is **offline as an operational practice**, not as a Kubernetes workload:

- No Root Deployment, Service, or Helm chart
- Root key lives in a dedicated Root KMS key
- Only `pki-admin` (via `sts:AssumeRole`) may use it
- Use: sign / renew Intermediate, Root rotation — not leaf issuance

KMS does not by itself mean “offline”. Isolation is IAM + never deploying Root.

## Alternatives

- Air-gapped HSM / offline disk key — stronger offline story, worse local fidelity and slower recovery
- Online Root in cluster — simpler ops, catastrophic blast radius

## Consequences

- Admin machine + assumed role is required for Intermediate renewal and Root rotation
- `step-ca` IAM must never include the Root key
- Org can later swap in a genuinely offline Root without changing the Intermediate online path
