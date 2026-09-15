# Conventions

Stable project-wide rules. Module internals stay in module READMEs.

## Folders

- `root-ca/` — offline Root only. Never a Kubernetes chart or `deploy/` subtree.
- `intermediate-ca/` — logical online CA config (provisioners, templates, example `ca.json`).
- `infrastructure/aws/` — Terraform. `local/` vs `prod/` roots; shared `modules/`.
- `deploy/helm/step-ca/` — online Intermediate. Env overlays: `values-{dev,prod}.yaml`.
- `docs/` — project-level only. Feature docs live next to the code.
- `local/` — gitignored artifacts. Never commit.

## Naming

- IAM: `pki-admin` (break-glass), `step-ca` (online CA)
- Placeholders: `REPLACE_ME`, `CHANGE_ME`, `example` — no fake-looking prod credentials
- Chart env files: `values-{env}.yaml`, not a generic `make deploy`

## Secrets

- No private keys, passwords, or AWS credentials in Git
- Intermediate signing key is KMS, not a Kubernetes Secret (except LocalStack assumed-role creds, local only)
- Refuse tracked `*.key` / `*.pem` / `*.p12` / `credentials.json` / `password.txt`

## Helm

Env overlays on top of `values.yaml`. Empty maps do **not** unset nested keys (Helm deep-merge). Do not put `capabilities.drop` in the base file if kind must omit it.

## Make

- Local lifecycle: `localstack-*`, `tf-apply-local`, `bootstrap-local`, `deploy-dev`
- No ambiguous production deploy target
- Lint/validate must stay safe to run on every change

## Docs

- Project docs explain organization, how to work, how parts connect, and where module docs live
- Link instead of copying runbooks, Terraform, or provisioner detail
- Add an [ADR](adr/) for hard-to-reverse choices; skip ADRs for routine edits

## Ownership

[CODEOWNERS](../CODEOWNERS): `root-ca/`, Root KMS module, and root-rotation runbook → `security-pki-admins`. Platform team owns deploy and the online CA path.
