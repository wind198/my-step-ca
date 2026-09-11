# Leaf workflow integration tests

Exercises common leaf workflows for:

- **K8SSA** — [`intermediate-ca/provisioners/k8ssa.md`](../intermediate-ca/provisioners/k8ssa.md)
- **External** — ACME + JWK ([`integrations/external-workloads/README.md`](../integrations/external-workloads/README.md))

Against local **kind** + **LocalStack** `step-ca` (see `make deploy-dev`).

## Prerequisites

```bash
make localstack-up
make tf-apply-local
make bootstrap-local   # enables ACME + K8SSA + JWK (dev) in local/config/ca.json
make deploy-dev
```

Requires: `kubectl`, `curl`, `jq`, `openssl`, `step` (external JWK tests), cluster images `smallstep/step-cli`, `curlimages/curl`, `nginx` (pull/load into kind if needed).

## Run

```bash
make test              # k8ssa + external (skips cleanly if CA missing)
make test-k8ssa
make test-external
```

Artifacts: gitignored `local/test-out/`.

## Suites

| Path | Coverage |
|------|----------|
| `k8ssa/01_health_and_roots.sh` | In-cluster `/health` + `/roots.pem` |
| `k8ssa/02_issue_allowed_san.sh` | SA `payments-api` → `payments-api.payments.svc.cluster.local` |
| `k8ssa/03_deny_arbitrary_san.sh` | Evil SAN overwritten/rejected by K8SSA template |
| `k8ssa/04_renew_leaf.sh` | Two issues; notAfter non-decreasing |
| `external/01_health_and_roots.sh` | Host port-forward health + roots |
| `external/02_acme_issue.sh` | ACME directory + HTTP-01 leaf via Job |
| `external/03_jwk_issue_and_renew.sh` | Dev JWK `external-test` issue + renew |
| `external/04_deny_without_auth.sh` | Unauthed `/1.0/sign` not 200 |

JWK password lives in `local/secrets/external-test.password` (**dev-only**, never commit).

K8SSA jobs use a **legacy** SA token Secret (`type: kubernetes.io/service-account-token`) because step-ca does not accept bound tokens (`iss=https://kubernetes.default.svc...`).
