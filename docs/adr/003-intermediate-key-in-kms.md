# 003 — Intermediate signing key in KMS

## Context

`step-ca` needs a private key to sign leaves. Storing a PEM in a Kubernetes Secret is operationally easy and a high-value target if the cluster or git is compromised.

## Decision

Intermediate private key stays in **AWS KMS** (LocalStack KMS locally). `step-ca` calls `kms:Sign` and `kms:GetPublicKey` only.

- Not a Kubernetes Secret, ConfigMap, image, or git file
- Pod identity: IRSA / Pod Identity in staging/prod; assumed-role Secret **local only**

## Alternatives

- PEM in a Secret / sealed-secrets — simpler local debug, key exportable from the cluster
- Soft HSM in-process — no KMS dependency, weaker isolation from the CA process

## Consequences

- Cluster rebuild does not recover the key (KMS durability does)
- Redeploying the container is not a full CA recovery; cert, `ca.json`, provisioners, and DB/state still matter
- Local path must point pods at LocalStack (`AWS_ENDPOINT_URL` on the docker bridge, not `localhost`)
