# CA recovery

## Symptoms

- Cannot issue certificates
- KMS authorization failures
- Lost Intermediate certificate / DB state
- Cluster destroyed

## Actions

1. Confirm KMS keys still exist (admin role)
2. Restore Intermediate cert + `ca.json` + provisioners from backup
3. Redeploy Helm; reattach IRSA / LocalStack endpoint
4. Verify `kms:Sign` and chain
5. If Root compromised: follow `root-rotation.md` — do not reuse Root key
