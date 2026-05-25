# SealedSecrets generation guide

This directory contains scripts used by operators or CI jobs to generate Kubernetes SealedSecrets from local plaintext inputs.

The plaintext inputs must never be committed. Keep real values only in `secrets-raw/*.env` on your workstation, Jenkins credentials store, or another approved secret manager.

## Prerequisites

Install these tools on the machine that generates SealedSecrets:

```bash
kubectl version --client
kubeseal --version
```

The script talks to the cluster to fetch the SealedSecrets controller certificate. For this project, use the K3s kubeconfig:

```bash
export KUBECONFIG=./.kube/k3s-config.yaml
```

The script also sets this default internally if `KUBECONFIG` is not already set.

## Input files

Use the examples in `secrets-raw/`:

```bash
cp secrets-raw/dev.env.example secrets-raw/dev.env
cp secrets-raw/stage.env.example secrets-raw/stage.env
cp secrets-raw/ephemeral-shared.env.example secrets-raw/ephemeral-shared.env
```

Then edit the copied `.env` files and replace every placeholder value with the real secret.

Do not edit the `.env.example` files with real secrets. They are committed as documentation only.

## Required variables

Every environment file must define exactly these keys:

```bash
POSTGRESQL_USERNAME=
POSTGRESQL_PASSWORD=
ELASTICSEARCH_USERNAME=
ELASTICSEARCH_PASSWORD=
KEYCLOAK_BACKOFFICE_BFF_CLIENT_SECRET=
KEYCLOAK_STOREFRONT_BFF_CLIENT_SECRET=
KEYCLOAK_CUSTOMER_MANAGEMENT_CLIENT_SECRET=
REDIS_PASSWORD=
OPENAI_API_KEY=
KEYCLOAK_ADMIN_USERNAME=
KEYCLOAK_ADMIN_PASSWORD=
PGADMIN_PASSWORD=
GRAFANA_USERNAME=
GRAFANA_PASSWORD=
```

## Generate SealedSecrets

Development environment:

```bash
export KUBECONFIG=./.kube/k3s-config.yaml
scripts/generate-sealed-secrets.sh dev
```

Stage environment:

```bash
export KUBECONFIG=./.kube/k3s-config.yaml
scripts/generate-sealed-secrets.sh stage
```

Ephemeral shared secrets:

```bash
export KUBECONFIG=./.kube/k3s-config.yaml
scripts/generate-sealed-secrets.sh ephemeral-shared
```

The script writes SealedSecrets to:

```text
sealed-secrets/dev/
sealed-secrets/stage/
sealed-secrets/ephemeral-shared/
```

## Scope rules

`dev` uses namespace-wide scope for namespace `yas-dev`.

`stage` uses namespace-wide scope for namespace `yas-stage`.

`ephemeral-shared` uses cluster-wide scope so the same sealed secret can be used by dynamic preview namespaces.

## Validate output

Run this before committing:

```bash
find sealed-secrets/ -name "*.yaml" -not -name kustomization.yaml -exec kubeseal --validate {} \;
kubectl kustomize overlays/dev > /tmp/yas-dev.yaml
kubectl kustomize overlays/stage > /tmp/yas-stage.yaml
kubectl kustomize overlays/ephemeral > /tmp/yas-ephemeral.yaml
```

If `kustomize` is installed separately, these are equivalent:

```bash
kustomize build overlays/dev
kustomize build overlays/stage
kustomize build overlays/ephemeral
```

## Commit policy

Commit:

```text
sealed-secrets/<env>/*.yaml
sealed-secrets/<env>/kustomization.yaml
```

Do not commit:

```text
secrets-raw/*.env
*.secret.yaml
*.secret.yml
```

The `.gitignore` file is configured to allow only `secrets-raw/*.env.example` and `secrets-raw/README.md`.

## Rotation workflow

1. Update the real value in `secrets-raw/<env>.env`.
2. Run `scripts/generate-sealed-secrets.sh <env>`.
3. Validate with `kubeseal --validate`.
4. Commit only the regenerated SealedSecret YAML files.
5. Let ArgoCD sync the updated SealedSecret.
