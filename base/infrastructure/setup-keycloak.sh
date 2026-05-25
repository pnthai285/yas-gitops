#!/bin/bash
set -euo pipefail
set -x

export KUBECONFIG="${KUBECONFIG:-./.kube/k3s-config.yaml}"

#Read configuration value from cluster-config.yaml file
mapfile -t keycloak_cfg < <(yq eval -r '
  .domain,
  .postgresql.username,
  .keycloak.bootstrapAdmin.username,
  .keycloak.backofficeRedirectUrl,
  .keycloak.storefrontRedirectUrl
' ./base/infrastructure/cluster-config.yaml)

DOMAIN="${keycloak_cfg[0]}"
POSTGRESQL_USERNAME="${keycloak_cfg[1]}"
BOOTSTRAP_ADMIN_USERNAME="${keycloak_cfg[2]}"
KEYCLOAK_BACKOFFICE_REDIRECT_URL="${keycloak_cfg[3]}"
KEYCLOAK_STOREFRONT_REDIRECT_URL="${keycloak_cfg[4]}"

KEYCLOAK_NAMESPACE="${KEYCLOAK_NAMESPACE:-keycloak}"
KEYCLOAK_POSTGRESQL_SECRET="${KEYCLOAK_POSTGRESQL_SECRET:-postgresql-credentials}"
KEYCLOAK_BOOTSTRAP_ADMIN_SECRET="${KEYCLOAK_BOOTSTRAP_ADMIN_SECRET:-keycloak-credentials}"
KEYCLOAK_CREATE_MISSING_SECRETS="${KEYCLOAK_CREATE_MISSING_SECRETS:-false}"

warn_ingress_nginx() {
  if kubectl get svc ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
    return 0
  fi

  echo "WARN: ingress-nginx controller service was not found." >&2
  echo "WARN: Keycloak resources can still be installed, but external routing will not work until ingress-nginx is installed." >&2
}

ensure_secret_exists() {
  secret_name="$1"
  username_key="$2"
  username_value="$3"
  password_key="$4"
  password_env_name="$5"

  if kubectl get secret "$secret_name" -n "$KEYCLOAK_NAMESPACE" >/dev/null 2>&1; then
    return 0
  fi

  if [ "$KEYCLOAK_CREATE_MISSING_SECRETS" != "true" ]; then
    echo "ERROR: Missing secret $KEYCLOAK_NAMESPACE/$secret_name." >&2
    echo "Apply the matching SealedSecret first, or rerun with KEYCLOAK_CREATE_MISSING_SECRETS=true and $password_env_name set locally." >&2
    exit 1
  fi

  password_value="${!password_env_name:-}"
  if [ -z "$password_value" ]; then
    echo "ERROR: $password_env_name is required when KEYCLOAK_CREATE_MISSING_SECRETS=true." >&2
    exit 1
  fi

  kubectl create secret generic "$secret_name" \
    -n "$KEYCLOAK_NAMESPACE" \
    --from-literal="$username_key=$username_value" \
    --from-literal="$password_key=$password_value"
}

warn_ingress_nginx

#Install CRD keycloak
kubectl create namespace "$KEYCLOAK_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

ensure_secret_exists "$KEYCLOAK_POSTGRESQL_SECRET" \
  username "$POSTGRESQL_USERNAME" \
  password KEYCLOAK_POSTGRESQL_PASSWORD

ensure_secret_exists "$KEYCLOAK_BOOTSTRAP_ADMIN_SECRET" \
  username "$BOOTSTRAP_ADMIN_USERNAME" \
  password KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD

kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.2/kubernetes/kubernetes.yml -n "$KEYCLOAK_NAMESPACE"

# Install keycloak
helm upgrade --install keycloak ./base/infrastructure/keycloak/keycloak \
--namespace "$KEYCLOAK_NAMESPACE" \
--set hostname="identity.$DOMAIN" \
--set postgresql.existingSecret="$KEYCLOAK_POSTGRESQL_SECRET" \
--set postgresql.createSecret=false \
--set bootstrapAdmin.existingSecret="$KEYCLOAK_BOOTSTRAP_ADMIN_SECRET" \
--set bootstrapAdmin.createSecret=false \
--set backofficeRedirectUrl="$KEYCLOAK_BACKOFFICE_REDIRECT_URL" \
--set storefrontRedirectUrl="$KEYCLOAK_STOREFRONT_REDIRECT_URL"
