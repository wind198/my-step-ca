# External (non-Kubernetes) workloads

Use short-lived certificates from Intermediate CA via:

- ACME
- OIDC / JWK admin provisioners
- Device identity flows (org-specific)

Distribute Root CA certificate as trust anchor. Never distribute Intermediate private key.

Do not give every external service an unrestricted JWK/password provisioner.

Leaf-facing contract (K8s preferred path + ACME notes): [`docs/interfaces/leaf-service.md`](../../docs/interfaces/leaf-service.md).

Integration tests: [`test/README.md`](../../test/README.md) (`make test-external`).
