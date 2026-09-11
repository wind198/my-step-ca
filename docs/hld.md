# Company Private PKI — Repository Context for AI Agent

## 1. Purpose

Scaffold a production-oriented private PKI repository for a company using:

* `step-ca` as the online Certificate Authority
* Kubernetes as the runtime platform for the online Intermediate CA
* An offline/on-prem administrative environment for the Root CA
* AWS KMS for CA private-key protection
* Kubernetes Service Account identity (`K8SSA`) for workload authentication
* Short-lived workload certificates
* Optional `cert-manager` integration for Kubernetes workloads

The repository must clearly separate:

1. Offline Root CA lifecycle
2. Online Intermediate CA configuration
3. AWS KMS/IAM infrastructure
4. Kubernetes deployment
5. Workload certificate integration
6. Operational documentation and recovery procedures

The scaffold must **not contain real private keys, credentials, tokens, passwords, or production secrets**.

---

# 2. Target Architecture

The intended PKI hierarchy is:

```text
                    OFFLINE / ADMIN ENVIRONMENT

                       ┌──────────────────┐
                       │    Root CA       │
                       │                  │
                       │ Offline         │
                       │ Long-lived      │
                       └────────┬─────────┘
                                │
                       signs Intermediate
                                │
                                ▼

                         ONLINE ENVIRONMENT

                 ┌──────────────────────────┐
                 │      AWS KMS              │
                 │                          │
                 │ Intermediate CA key      │
                 │ Non-exportable           │
                 └────────────┬─────────────┘
                              │
                           kms:Sign
                              │
                              ▼
                 ┌──────────────────────────┐
                 │       Kubernetes         │
                 │                          │
                 │       step-ca            │
                 │                          │
                 │  Intermediate CA         │
                 │  2+ replicas             │
                 └────────────┬─────────────┘
                              │
                         certificate
                          issuance
                              │
              ┌───────────────┼────────────────┐
              ▼               ▼                ▼
          Service A       Service B        Service C
```

The Root CA is **not** an always-running Kubernetes workload.

The Intermediate CA is the online CA used for routine certificate issuance.

The Kubernetes `step-ca` pods must never have access to the Root CA private key.

---

# 3. Security Principles

The implementation must follow these principles.

## 3.1 Root CA isolation

The Root CA is an offline trust anchor.

It must:

* not run as a Kubernetes Deployment
* not be reachable from normal workloads
* not have its private key stored in Git
* not be accessible by the Kubernetes `step-ca` IAM role
* only be used for exceptional PKI operations such as:

  * signing an Intermediate CA
  * renewing/replacing an Intermediate CA
  * Root CA rotation

If Root CA signing uses AWS KMS, access must be strongly isolated from the production Kubernetes IAM role.

If the organization requires a genuinely offline root, support an offline/on-prem root key implementation instead.

Do not silently assume that "stored in AWS KMS" means "offline".

---

## 3.2 Intermediate CA key protection

The online Intermediate CA private signing key must be backed by AWS KMS.

The private key must not be:

* committed to Git
* stored as plaintext in a Kubernetes Secret
* embedded in a ConfigMap
* baked into a container image
* copied between Kubernetes pods

`step-ca` should use AWS KMS signing operations.

The Kubernetes workload identity used by `step-ca` should receive only the minimum KMS permissions required.

At minimum, design around:

```text
kms:GetPublicKey
kms:Sign
```

Do not grant the `step-ca` workload access to the Root CA signing key.

---

## 3.3 Kubernetes AWS identity

Do not put static AWS access keys into Kubernetes Secrets.

Use AWS workload identity appropriate to the target platform, such as:

* EKS Pod Identity
* IRSA

The scaffold should make the IAM relationship explicit.

---

## 3.4 No secrets in Git

Never create fake-looking production credentials.

Use placeholders such as:

```text
REPLACE_ME
CHANGE_ME
example
```

or Kubernetes Secret references without actual secret values.

Never generate:

```text
*.key
*.pem
*.p12
*.pfx
credentials.json
aws-access-key.json
password.txt
```

containing private or credential material.

It is acceptable to include:

```text
example/
```

files containing clearly non-functional example values.

---

# 4. Repository Strategy

Prefer two repositories logically:

```text
company-pki-root
company-pki-platform
```

However, this scaffold may initially be implemented as a single repository with explicit directory boundaries.

If using one repository, make the security boundary obvious and prepare for later extraction of `root-ca/` into a separate restricted repository.

Recommended structure:

```text
company-pki/
├── README.md
├── Makefile
├── .gitignore
├── .editorconfig
├── CODEOWNERS
│
├── docs/
│   ├── architecture.md
│   ├── threat-model.md
│   ├── certificate-policy.md
│   ├── disaster-recovery.md
│   └── runbooks/
│       ├── bootstrap.md
│       ├── intermediate-renewal.md
│       ├── root-rotation.md
│       ├── ca-recovery.md
│       └── incident-response.md
│
├── root-ca/
│   ├── README.md
│   ├── config/
│   │   └── root-ca.json.example
│   ├── policy/
│   │   └── root-policy.md
│   └── scripts/
│       ├── init-root.sh
│       ├── generate-intermediate-csr.sh
│       ├── sign-intermediate.sh
│       └── verify-chain.sh
│
├── intermediate-ca/
│   ├── README.md
│   ├── config/
│   │   ├── ca.json.example
│   │   └── templates/
│   │       ├── tls.json
│   │       └── workload.json
│   ├── provisioners/
│   │   ├── k8ssa.md
│   │   └── admins.md
│   └── scripts/
│       ├── bootstrap.sh
│       ├── verify.sh
│       └── healthcheck.sh
│
├── infrastructure/
│   └── aws/
│       ├── kms/
│       │   ├── root/
│       │   └── intermediate/
│       └── iam/
│           ├── step-ca/
│           └── admin/
│
├── deploy/
│   ├── helm/
│   │   └── step-ca/
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       ├── values-dev.yaml
│   │       ├── values-staging.yaml
│   │       ├── values-prod.yaml
│   │       └── templates/
│   │           ├── deployment.yaml
│   │           ├── service.yaml
│   │           ├── serviceaccount.yaml
│   │           ├── configmap.yaml
│   │           ├── networkpolicy.yaml
│   │           ├── pdb.yaml
│   │           └── servicemonitor.yaml
│   │
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
│
├── integrations/
│   ├── cert-manager/
│   │   ├── clusterissuer.yaml
│   │   └── certificate-examples/
│   │
│   └── external-workloads/
│       └── README.md
│
└── scripts/
    ├── lint.sh
    ├── validate.sh
    └── verify-chain.sh
```

---

# 5. Root CA Directory

The `root-ca/` directory contains tooling and documentation for offline Root CA administration.

It should not depend on Kubernetes.

Example:

```text
root-ca/
├── README.md
├── config/
│   └── root-ca.json.example
├── policy/
│   └── root-policy.md
└── scripts/
    ├── init-root.sh
    ├── generate-intermediate-csr.sh
    ├── sign-intermediate.sh
    └── verify-chain.sh
```

The scripts should be conservative and fail safely.

Use:

```bash
set -euo pipefail
```

where appropriate.

Scripts should validate required inputs and refuse to operate if paths or parameters are ambiguous.

Do not make scripts destructive by default.

Prefer explicit flags such as:

```text
--environment
--output
--csr
--certificate
--profile
```

over implicit paths.

---

# 6. Intermediate CA

The `intermediate-ca/` directory represents the logical configuration of the online CA.

It must remain conceptually independent from the Kubernetes deployment mechanism.

Example:

```text
intermediate-ca/
├── README.md
├── config/
│   ├── ca.json.example
│   └── templates/
│       ├── tls.json
│       └── workload.json
├── provisioners/
│   ├── k8ssa.md
│   └── admins.md
└── scripts/
    ├── bootstrap.sh
    ├── verify.sh
    └── healthcheck.sh
```

The configuration should document:

* CA name
* certificate lifetime
* maximum certificate lifetime
* provisioners
* allowed identities
* Kubernetes Service Account authentication
* administrative authentication
* certificate profiles
* audit requirements

Avoid putting environment-specific values directly into the logical CA configuration.

---

# 7. K8SSA Provisioner

The preferred Kubernetes workload authentication mechanism is the `step-ca` Kubernetes Service Account provisioner.

Conceptually:

```text
Pod
 │
 │ Kubernetes ServiceAccount token
 ▼
step-ca
 │
 │ validate workload identity
 ▼
issue certificate
```

The design should prevent arbitrary workloads from obtaining arbitrary DNS identities.

Document the relationship between:

```text
Kubernetes namespace
Kubernetes ServiceAccount
allowed certificate identity / SAN
certificate lifetime
```

Example conceptual policy:

```text
namespace:
    payments

serviceAccount:
    payments-api

allowed identity:
    payments-api.payments.svc.cluster.local
```

Do not implement an unrestricted "any ServiceAccount can request any certificate" policy.

---

# 8. Kubernetes Deployment

The Helm chart should deploy the online `step-ca`.

The deployment should support:

* multiple replicas
* Kubernetes Service
* dedicated ServiceAccount
* AWS workload identity annotations/configuration
* ConfigMap for non-secret configuration
* Secret references for bootstrap/runtime values where necessary
* readiness probe
* liveness probe
* PodDisruptionBudget
* NetworkPolicy
* securityContext
* resource requests/limits
* topology spread or anti-affinity
* graceful termination
* Prometheus monitoring where supported

Recommended baseline:

```text
replicas: 2
```

Production values may increase this.

---

# 9. Pod Security

The Helm deployment should follow Kubernetes hardening best practices.

Prefer:

```yaml
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

Also consider:

```yaml
capabilities:
  drop:
    - ALL
```

Do not add Linux capabilities unless required by the application.

Do not run the CA container as privileged.

Do not use:

```yaml
hostNetwork: true
hostPID: true
hostPath:
```

unless there is a documented requirement.

---

# 10. NetworkPolicy

The CA should not be reachable by every workload by default.

NetworkPolicy should restrict access to expected clients.

For example:

```text
cert-manager
        │
        ▼
     step-ca

authorized workloads
        │
        ▼
     step-ca
```

Ingress should be restricted to known namespaces/service accounts where practical.

Egress should be restricted to required dependencies, especially:

```text
AWS KMS endpoints
DNS
required AWS APIs
```

Avoid an unrestricted:

```yaml
egress:
  - {}
```

unless explicitly documented as a temporary development setting.

---

# 11. AWS KMS

Create separate logical KMS resources for:

```text
Root CA
Intermediate CA
```

Never reuse the same KMS key for unrelated purposes.

The intermediate CA key should be usable by the Kubernetes `step-ca` IAM role.

The root CA key, if KMS-backed, must not be usable by the Kubernetes role.

Conceptual permission model:

```text
                    Root CA KMS key
                           │
                    ┌──────┴──────┐
                    │             │
                 Admin        step-ca
                  YES            NO


              Intermediate CA KMS key
                           │
                           ▼
                       step-ca
                          YES
```

The IaC should use least privilege.

Do not use:

```text
Action: kms:*
Resource: *
```

in the production IAM policy.

---

# 12. Infrastructure as Code

AWS infrastructure may be implemented using Terraform unless the existing project specifies another IaC tool.

If Terraform is used, structure it approximately as:

```text
infrastructure/aws/
├── kms/
│   ├── root/
│   └── intermediate/
└── iam/
    ├── step-ca/
    └── admin/
```

Do not hard-code:

* AWS account IDs
* production role ARNs
* KMS key IDs
* cluster IDs
* credentials

Use variables and documented placeholders.

Prefer outputs such as:

```text
intermediate_ca_kms_key_arn
step_ca_role_arn
root_ca_kms_key_arn
```

where appropriate.

---

# 13. Helm Values

Keep environment-specific values small.

Base:

```text
deploy/helm/step-ca/values.yaml
```

Environment overrides:

```text
deploy/helm/step-ca/values-dev.yaml
deploy/helm/step-ca/values-staging.yaml
deploy/helm/step-ca/values-prod.yaml
```

Do not duplicate the entire configuration in each file.

Production values should explicitly configure:

* replicas
* resource requests
* resource limits
* pod disruption budget
* topology spread / anti-affinity
* service exposure
* network policy
* AWS workload identity
* monitoring

---

# 14. CA Configuration and Kubernetes Secrets

Distinguish carefully between:

### Non-secret configuration

May be stored in:

```text
ConfigMap
```

Examples:

* CA configuration
* certificate chain
* URLs
* non-sensitive policy configuration

### Secret material

Must not be committed.

Examples:

* bootstrap tokens
* provisioner secrets
* passwords
* external credentials

The Intermediate CA private signing key should **not** be represented as a Kubernetes Secret when using AWS KMS-backed signing.

---

# 15. Certificate Chain

The expected trust chain is:

```text
Root CA certificate
        │
        ▼
Intermediate CA certificate
        │
        ▼
Workload certificate
```

The Root CA certificate is distributed as a trust anchor to systems that need to trust the company's PKI.

Workloads generally receive:

```text
leaf certificate
private key
intermediate certificate / chain
```

The private key belongs to the workload and is not the CA signing key.

---

# 16. cert-manager Integration

Provide an optional integration under:

```text
integrations/cert-manager/
```

Example:

```text
integrations/cert-manager/
├── clusterissuer.yaml
└── certificate-examples/
```

The integration should demonstrate how Kubernetes workloads can request certificates from `step-ca`.

Keep this integration optional.

The core `step-ca` deployment must not depend on `cert-manager`.

Document:

```text
workload
   │
   ▼
cert-manager
   │
   ▼
step-ca
   │
   ▼
AWS KMS
```

---

# 17. Observability

Provide baseline observability configuration.

Include:

* health endpoint configuration
* Kubernetes readiness/liveness probes
* Prometheus ServiceMonitor if Prometheus Operator is expected
* useful CA metrics where supported
* structured logs
* audit/logging guidance

Do not expose administrative endpoints publicly.

Document what should be monitored:

```text
CA availability
certificate issuance failures
certificate renewal failures
KMS authorization failures
KMS throttling/errors
certificate expiry
Intermediate CA expiry
Root CA expiry
```

---

# 18. Backup and Disaster Recovery

Document that CA recovery differs between Root and Intermediate CA.

## Root CA

Recovery depends on the offline root-key storage mechanism.

The organization must maintain:

* Root CA certificate
* Root CA private-key recovery procedure
* root configuration
* secure backup
* recovery credentials/material
* documented authorized operators

## Intermediate CA

Recovery should rely on:

* AWS KMS key durability
* reproducible Kubernetes deployment
* CA configuration
* Intermediate CA certificate
* required `step-ca` database/state
* provisioner configuration

Do not assume that redeploying the container alone is sufficient.

Explicitly document which `step-ca` state is persistent and how it is recovered.

---

# 19. Intermediate CA Renewal

Provide a runbook for:

```text
Generate new Intermediate CSR
        │
        ▼
Offline Root signs CSR
        │
        ▼
Deploy new Intermediate certificate
        │
        ▼
Validate chain
        │
        ▼
Switch/roll online CA
        │
        ▼
Verify certificate issuance
```

The runbook must include a rollback strategy.

Never make renewal dependent on an online Root CA.

---

# 20. Root Rotation

Provide a high-level runbook for Root CA rotation.

It should cover:

1. Generate new Root CA
2. Publish new trust anchor
3. Create new Intermediate CA
4. Sign new Intermediate with new Root
5. Deploy new Intermediate
6. Support trust overlap
7. Migrate workloads
8. Retire old Root only after the required trust period

Do not implement automatic root rotation.

Root rotation is an explicit security operation.

---

# 21. CODEOWNERS

If this is a single repository, protect the Root CA directory separately.

Conceptually:

```text
/root-ca/                    @security-pki-admins
/infrastructure/aws/kms/root/ @security-pki-admins
/docs/runbooks/root-rotation.md @security-pki-admins
```

The online platform areas can have different owners:

```text
/deploy/                     @platform-team
/intermediate-ca/            @platform-team @security-pki-admins
/infrastructure/aws/iam/     @platform-team @security-team
```

Use placeholder GitHub/GitLab team names if the actual organization is unknown.

---

# 22. CI Validation

Create CI validation for:

### YAML

* YAML syntax
* Kubernetes manifest validation
* Helm template rendering

### Helm

Run:

```text
helm lint
helm template
```

for each environment.

### Terraform

If Terraform is used:

```text
terraform fmt -check
terraform validate
```

Do not run `terraform apply` automatically from pull requests.

### Security

Scan for:

* private keys
* credentials
* AWS access keys
* Kubernetes Secrets containing obvious secret values
* accidental PEM files
* insecure IAM wildcard permissions

Useful tools may include:

```text
gitleaks
trivy
kubeconform
helm lint
terraform validate
```

Use tools only when they are appropriate for the actual project.

---

# 23. Makefile

Provide developer/operator convenience commands such as:

```text
make lint
make validate
make helm-lint
make helm-template
make verify-chain
make docs
```

Potentially:

```text
make deploy-dev
```

but do not create commands that can accidentally modify production.

Production operations should require explicit environment selection.

Avoid dangerous defaults such as:

```text
make deploy
```

implicitly targeting production.

---

# 24. README

The root README must explain:

1. What this repository is
2. Architecture
3. Root vs Intermediate responsibilities
4. AWS KMS role
5. Kubernetes role
6. Repository structure
7. Bootstrap sequence
8. Development workflow
9. Production deployment workflow
10. Secret handling
11. Disaster recovery
12. Security assumptions

Include an architecture diagram using plain Markdown/ASCII so it renders without external tooling.

---

# 25. Bootstrap Flow

Document the intended bootstrap sequence:

```text
Phase 1 — AWS infrastructure
    │
    ├── Create KMS resources
    └── Create IAM roles/policies
    │
    ▼
Phase 2 — Offline Root
    │
    ├── Initialize Root CA
    ├── Generate Intermediate key/CSR
    └── Root signs Intermediate
    │
    ▼
Phase 3 — Online CA
    │
    ├── Configure step-ca
    ├── Configure AWS KMS
    ├── Configure K8SSA provisioner
    └── Deploy to Kubernetes
    │
    ▼
Phase 4 — Integration
    │
    ├── Configure trust bundle
    ├── Configure cert-manager if required
    └── Issue test certificate
    │
    ▼
Phase 5 — Verification
    │
    ├── Verify certificate chain
    ├── Verify KMS signing
    ├── Verify workload identity
    └── Verify renewal
```

---

# 26. What the AI Agent Must NOT Do

Do not:

* generate real private keys
* generate real AWS credentials
* generate production passwords
* commit Kubernetes Secrets containing secret values
* put CA private keys into ConfigMaps
* put the Intermediate CA private key into a Kubernetes Secret when KMS-backed signing is used
* give Kubernetes access to the Root CA key
* deploy the Root CA into Kubernetes
* make the Root CA online
* grant `kms:*` to the `step-ca` role
* use `Resource: "*"` for sensitive KMS permissions unless technically unavoidable and explicitly documented
* create unrestricted certificate issuance policies
* allow every Kubernetes ServiceAccount to request arbitrary DNS names
* automatically rotate the Root CA
* silently invent AWS account IDs, regions, cluster names, domains, or organization-specific DNS names
* create production DNS names without configuration variables
* assume EKS if the target Kubernetes environment has not been explicitly specified
* introduce external dependencies without documenting them

---

# 27. What the AI Agent SHOULD Do

The agent should:

* scaffold all directories
* create useful README files
* create safe `.example` configuration files
* create Helm templates
* create Kubernetes security policies
* create Terraform skeletons if Terraform is selected
* create validation scripts
* create operational runbooks
* add TODOs where organization-specific decisions are required
* use placeholders for unknown values
* make configuration composable
* keep secrets out of Git
* make the security boundaries obvious
* provide comments explaining security-sensitive decisions
* make the repository usable by another engineer without requiring undocumented context

---

# 28. Organization-Specific Values

Do not invent these values.

They must be configurable:

```text
COMPANY_DOMAIN
PKI_DOMAIN
AWS_REGION
AWS_ACCOUNT_ID
EKS_CLUSTER_NAME
KMS_KEY_ARN
STEP_CA_NAMESPACE
STEP_CA_SERVICE_ACCOUNT
ROOT_CA_NAME
INTERMEDIATE_CA_NAME
```

For example:

```yaml
global:
  organization: "Example Corp"
  domain: "example.internal"
```

is acceptable as an example, but it must be clearly non-production.

Prefer environment variables, Terraform variables, Helm values, or documented configuration files.

---

# 29. Definition of Done

The scaffold is considered complete when:

* [ ] Repository structure exists
* [ ] Root CA and Intermediate CA responsibilities are clearly separated
* [ ] Root CA is not deployed to Kubernetes
* [ ] AWS KMS integration is represented
* [ ] IAM least-privilege structure is represented
* [ ] Kubernetes `step-ca` Helm chart exists
* [ ] Production values are separate from development defaults
* [ ] Kubernetes workload identity is represented
* [ ] K8SSA provisioner is documented/configured safely
* [ ] Certificate lifetime policy is represented
* [ ] NetworkPolicy exists
* [ ] Pod security hardening exists
* [ ] PDB exists
* [ ] Health/readiness probes exist
* [ ] Observability configuration exists
* [ ] cert-manager integration is optional
* [ ] Root CA bootstrap procedure exists
* [ ] Intermediate CA renewal procedure exists
* [ ] Root rotation procedure exists
* [ ] Disaster recovery procedure exists
* [ ] No real secrets/private keys exist in the repository
* [ ] Helm lint/template validation is possible
* [ ] Secret scanning is documented
* [ ] README explains the complete architecture
* [ ] Organization-specific values are not hard-coded

---

# 30. Implementation Philosophy

Prefer **boring, explicit, auditable infrastructure** over clever abstractions.

The most important property of this repository is not that it deploys `step-ca` quickly.

The most important property is that an engineer can answer:

> "What can compromise the Root CA?"

> "What can compromise the Intermediate CA?"

> "What AWS permissions does `step-ca` have?"

> "Which Kubernetes workloads are allowed to obtain certificates?"

> "Where are the CA private keys?"

> "How do we recover if Kubernetes is destroyed?"

> "How do we renew the Intermediate CA without bringing the Root CA online?"

Those answers should be obvious from the repository structure, configuration, IAM policies, and runbooks.

When there is a conflict between convenience and PKI security, **prefer the more secure and auditable design** and document the operational trade-off.
