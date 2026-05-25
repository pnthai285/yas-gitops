
set -x

# Auto restart when change configmap or secret
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

DOMAIN="${DOMAIN:-$(yq -r '.domain' ./base/infrastructure/cluster-config.yaml)}"
NAMESPACE="${NAMESPACE:-yas-dev}"
API_HOST="${API_HOST:-api.$DOMAIN}"
IDENTITY_HOST="${IDENTITY_HOST:-identity.$DOMAIN}"
BACKOFFICE_HOST="${BACKOFFICE_HOST:-backoffice.$DOMAIN}"
STOREFRONT_HOST="${STOREFRONT_HOST:-storefront.$DOMAIN}"

helm dependency build base/microservices/yas-configuration
helm upgrade --install yas-configuration base/microservices/yas-configuration \
--namespace "$NAMESPACE" --create-namespace \
--set global.domain="$DOMAIN" \
--set global.apiHost="$API_HOST" \
--set global.apiUrl="https://$API_HOST" \
--set global.identityHost="$IDENTITY_HOST" \
--set global.identityUrl="https://$IDENTITY_HOST" \
--set global.backofficeHost="$BACKOFFICE_HOST" \
--set global.storefrontHost="$STOREFRONT_HOST" \
--set global.storefrontUrl="http://$STOREFRONT_HOST"
