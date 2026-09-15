# Production (EKS)

Use [`values-prod.yaml`](../../helm/step-ca/values-prod.yaml). Explicit approval required. **No** `make deploy`.

Identity: IRSA on the `step-ca` ServiceAccount (`eks.amazonaws.com/role-arn`). Do not set `aws.credentialsSecretName` — that Secret path is kind/LocalStack only.

```bash
helm upgrade --install step-ca deploy/helm/step-ca \
  --namespace step-ca \
  -f deploy/helm/step-ca/values.yaml \
  -f deploy/helm/step-ca/values-prod.yaml
```
