# 001 — Single repo with explicit Root vs online-CA boundary

## Context

Root CA material is more sensitive than online Intermediate config and Helm. Two repos (`company-pki-root` vs `company-pki-platform`) would match that boundary. This scaffold started as one repository.

## Decision

Keep a **single repo** with hard directory boundaries:

- `root-ca/` — offline Root only; never under `deploy/`
- `intermediate-ca/`, `deploy/`, `infrastructure/aws/` — online path

CODEOWNERS restrict Root and root-rotation docs to PKI admins. Prepare to extract `root-ca/` later if the org splits repos.

## Alternatives

- Two repos from day one — stronger isolation, slower bootstrap and local fidelity
- Mix Root scripts into the Helm chart — weaker boundary, easy to deploy Root by mistake

## Consequences

- Reviewers must treat `root-ca/` as a separate trust domain
- One clone is enough for local kind + LocalStack
- A later split is a move of `root-ca/` plus IAM/CODEOWNERS, not a redesign
