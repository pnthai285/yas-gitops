#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-./.kube/k3s-config.yaml}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate-sealed-secrets.sh dev
  scripts/generate-sealed-secrets.sh stage
  scripts/generate-sealed-secrets.sh ephemeral-shared

Input files are local-only and ignored by git:
  secrets-raw/dev.env
  secrets-raw/stage.env
  secrets-raw/ephemeral-shared.env

Required keys:
  POSTGRESQL_USERNAME
  POSTGRESQL_PASSWORD
  ELASTICSEARCH_USERNAME
  ELASTICSEARCH_PASSWORD
  KEYCLOAK_BACKOFFICE_BFF_CLIENT_SECRET
  KEYCLOAK_STOREFRONT_BFF_CLIENT_SECRET
  KEYCLOAK_CUSTOMER_MANAGEMENT_CLIENT_SECRET
  REDIS_PASSWORD
  OPENAI_API_KEY
  KEYCLOAK_ADMIN_USERNAME
  KEYCLOAK_ADMIN_PASSWORD
  PGADMIN_PASSWORD
  GRAFANA_USERNAME
  GRAFANA_PASSWORD
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_var() {
  var_name="$1"
  if [ -z "${!var_name:-}" ]; then
    echo "Missing required variable ${var_name} in ${RAW_FILE}" >&2
    exit 1
  fi
}

seal_secret() {
  secret_name="$1"
  namespace="$2"
  scope="$3"
  output_file="$4"
  shift 4

  scope_flag="--scope=${scope}"
  kubectl create secret generic "$secret_name" \
    --namespace "$namespace" \
    --dry-run=client \
    -o yaml \
    "$@" \
    | kubeseal --format yaml "$scope_flag" > "$output_file"

  kubeseal --validate < "$output_file"
}

write_kustomization() {
  output_dir="$1"
  cat > "${output_dir}/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - yas-postgresql-credentials-secret.yaml
  - yas-elasticsearch-credentials-secret.yaml
  - yas-keycloak-credentials-secret.yaml
  - yas-redis-credentials-secret.yaml
  - yas-openai-api-key-secret.yaml
  - keycloak-credentials.yaml
  - postgresql-credentials.yaml
  - pgadmin-password.yaml
  - grafana-admin-credentials.yaml
  - postgresql-credentials-kafka.yaml
EOF
}

ENVIRONMENT="${1:-}"
case "$ENVIRONMENT" in
  dev)
    NAMESPACE="yas-dev"
    SCOPE="namespace-wide"
    ;;
  stage)
    NAMESPACE="yas-stage"
    SCOPE="namespace-wide"
    ;;
  ephemeral-shared)
    NAMESPACE="yas-preview"
    SCOPE="cluster-wide"
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

require_command kubectl
require_command kubeseal

RAW_FILE="secrets-raw/${ENVIRONMENT}.env"
OUTPUT_DIR="sealed-secrets/${ENVIRONMENT}"

if [ ! -f "$RAW_FILE" ]; then
  echo "Missing ${RAW_FILE}. Create it from the documented keys and keep it out of git." >&2
  exit 1
fi

set -a
. "$RAW_FILE"
set +a

for key in \
  POSTGRESQL_USERNAME \
  POSTGRESQL_PASSWORD \
  ELASTICSEARCH_USERNAME \
  ELASTICSEARCH_PASSWORD \
  KEYCLOAK_BACKOFFICE_BFF_CLIENT_SECRET \
  KEYCLOAK_STOREFRONT_BFF_CLIENT_SECRET \
  KEYCLOAK_CUSTOMER_MANAGEMENT_CLIENT_SECRET \
  REDIS_PASSWORD \
  OPENAI_API_KEY \
  KEYCLOAK_ADMIN_USERNAME \
  KEYCLOAK_ADMIN_PASSWORD \
  PGADMIN_PASSWORD \
  GRAFANA_USERNAME \
  GRAFANA_PASSWORD; do
  require_var "$key"
done

mkdir -p "$OUTPUT_DIR"

seal_secret "yas-postgresql-credentials-secret" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/yas-postgresql-credentials-secret.yaml" \
  --from-literal="POSTGRESQL_USERNAME=${POSTGRESQL_USERNAME}" \
  --from-literal="POSTGRESQL_PASSWORD=${POSTGRESQL_PASSWORD}"

seal_secret "yas-elasticsearch-credentials-secret" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/yas-elasticsearch-credentials-secret.yaml" \
  --from-literal="ELASTICSEARCH_USERNAME=${ELASTICSEARCH_USERNAME}" \
  --from-literal="ELASTICSEARCH_PASSWORD=${ELASTICSEARCH_PASSWORD}"

seal_secret "yas-keycloak-credentials-secret" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/yas-keycloak-credentials-secret.yaml" \
  --from-literal="KEYCLOAK_BACKOFFICE_BFF_CLIENT_SECRET=${KEYCLOAK_BACKOFFICE_BFF_CLIENT_SECRET}" \
  --from-literal="KEYCLOAK_STOREFRONT_BFF_CLIENT_SECRET=${KEYCLOAK_STOREFRONT_BFF_CLIENT_SECRET}" \
  --from-literal="KEYCLOAK_CUSTOMER_MANAGEMENT_CLIENT_SECRET=${KEYCLOAK_CUSTOMER_MANAGEMENT_CLIENT_SECRET}"

seal_secret "yas-redis-credentials-secret" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/yas-redis-credentials-secret.yaml" \
  --from-literal="REDIS_PASSWORD=${REDIS_PASSWORD}"

seal_secret "yas-openai-api-key-secret" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/yas-openai-api-key-secret.yaml" \
  --from-literal="OPENAI_API_KEY=${OPENAI_API_KEY}"

seal_secret "keycloak-credentials" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/keycloak-credentials.yaml" \
  --from-literal="username=${KEYCLOAK_ADMIN_USERNAME}" \
  --from-literal="password=${KEYCLOAK_ADMIN_PASSWORD}"

seal_secret "postgresql-credentials" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/postgresql-credentials.yaml" \
  --from-literal="username=${POSTGRESQL_USERNAME}" \
  --from-literal="password=${POSTGRESQL_PASSWORD}"

seal_secret "pgadmin-password" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/pgadmin-password.yaml" \
  --from-literal="pgadmin-password=${PGADMIN_PASSWORD}"

seal_secret "grafana-admin-credentials" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/grafana-admin-credentials.yaml" \
  --from-literal="username=${GRAFANA_USERNAME}" \
  --from-literal="password=${GRAFANA_PASSWORD}"

seal_secret "postgresql.credentials" "$NAMESPACE" "$SCOPE" "${OUTPUT_DIR}/postgresql-credentials-kafka.yaml" \
  --from-literal="username=${POSTGRESQL_USERNAME}" \
  --from-literal="password=${POSTGRESQL_PASSWORD}"

write_kustomization "$OUTPUT_DIR"
echo "Generated and validated SealedSecrets in ${OUTPUT_DIR}"
