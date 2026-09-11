# Online Intermediate CA (logical config)

Independent of Helm. Intermediate **signing key is AWS KMS** (or LocalStack KMS).

## Provisioners

- K8SSA — preferred for workloads (see `provisioners/k8ssa.md`)
- Admins — break-glass (see `provisioners/admins.md`)

## Bootstrap

Admin assume-role → create Intermediate cert (Root-signed) → deploy `ca.json` with:

```json
"key": "awskms:key-id=REPLACE_ME",
"kms": { "type": "awskms", "uri": "awskms:region=us-east-1" }
```
