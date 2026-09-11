# Root CA rotation

Manual security operation — not automated.

1. Generate new Root CA (new Root KMS key)
2. Publish new trust anchor (overlap period)
3. Create new Intermediate CA
4. Sign Intermediate with new Root
5. Deploy new Intermediate
6. Support trust overlap
7. Migrate workloads
8. Retire old Root only after required trust period

Diagram: [../workflows/rotate-root-ca.md](../workflows/rotate-root-ca.md)
