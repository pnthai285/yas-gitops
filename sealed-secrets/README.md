# SealedSecrets output

This directory contains encrypted SealedSecret manifests that are safe to commit.

Generate them with:

```bash
export KUBECONFIG=./.kube/k3s-config.yaml
scripts/generate-sealed-secrets.sh dev
scripts/generate-sealed-secrets.sh stage
scripts/generate-sealed-secrets.sh ephemeral-shared
```

Scopes:

```text
sealed-secrets/dev/              namespace-wide for yas-dev
sealed-secrets/stage/            namespace-wide for yas-stage
sealed-secrets/ephemeral-shared/ cluster-wide for dynamic preview namespaces
```

Validate before committing:

```bash
find sealed-secrets/ -name "*.yaml" -not -name kustomization.yaml -exec kubeseal --validate {} \;
```

The `kustomization.yaml` files in each environment are intentionally small. The generator rewrites them with the complete list of generated SealedSecret resources after a successful run.
