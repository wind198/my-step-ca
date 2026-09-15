# Architecture Decision Records

Record **why**, not how. How lives in runbooks and module docs.

Add an ADR when a choice is hard to reverse (trust boundary, key storage, authn, repo split, local vs prod path).

Skip ADRs for routine Helm/script tweaks.

## Index

- [001](001-single-repo-root-boundary.md) — single repo with explicit Root vs online-CA boundary
- [002](002-offline-root-kms.md) — offline Root via admin role + Root KMS
- [003](003-intermediate-key-in-kms.md) — Intermediate signing key in KMS
- [004](004-k8ssa-preferred-leaf-auth.md) — K8SSA preferred for in-cluster leaves
- [005](005-localstack-kind-fidelity.md) — LocalStack + kind; no casual prod deploy
