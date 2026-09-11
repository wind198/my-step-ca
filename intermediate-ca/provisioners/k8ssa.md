# K8SSA provisioner

```text
Pod SA token → step-ca validates → issue cert with constrained SAN
```

## Policy (conceptual)

```text
namespace: payments
serviceAccount: payments-api
allowed identity: payments-api.payments.svc.cluster.local
```

Do **not** allow every ServiceAccount to request arbitrary DNS names.

Leaf contract (issue / renew / trust): [`docs/interfaces/leaf-service.md`](../../docs/interfaces/leaf-service.md).

Integration tests: [`test/README.md`](../../test/README.md) (`make test-k8ssa`).

## Local / step-ca note

step-ca’s K8sSA provisioner expects **legacy** SA tokens (`iss=kubernetes/serviceaccount`). Bound tokens (default in modern Kubernetes) use the API server issuer and are rejected. Tests mount a `kubernetes.io/service-account-token` Secret and pass `--k8ssa-token-path`.

Template: [`../config/templates/k8ssa-workload.json`](../config/templates/k8ssa-workload.json) forces SAN from token SA name + namespace.
