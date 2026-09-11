# Admin provisioners

Break-glass issuance for operators (JWK or OIDC).

- Short lifetimes
- Separate from workload K8SSA
- Credentials never committed; store in sealed secrets / external secret manager

TODO: choose JWK vs OIDC for org.
