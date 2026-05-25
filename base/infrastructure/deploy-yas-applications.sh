#!/bin/bash
set -x

# Auto restart when change configmap or secret
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

read -rd '' DOMAIN \
< <(yq -r '.domain' ./base/infrastructure/cluster-config.yaml)

NAMESPACE="${NAMESPACE:-yas-dev}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
API_HOST="${API_HOST:-api.$DOMAIN}"
BACKOFFICE_HOST="${BACKOFFICE_HOST:-backoffice.$DOMAIN}"
STOREFRONT_HOST="${STOREFRONT_HOST:-storefront.$DOMAIN}"

helm dependency build base/microservices/backoffice-bff
helm upgrade --install backoffice-bff base/microservices/backoffice-bff \
--namespace "$NAMESPACE" --create-namespace \
--set global.environment="$ENVIRONMENT" \
--set global.backofficeHost="$BACKOFFICE_HOST"

helm dependency build base/microservices/backoffice-ui
helm upgrade --install backoffice-ui base/microservices/backoffice-ui \
--namespace "$NAMESPACE" --create-namespace

sleep 60

helm dependency build base/microservices/storefront-bff
helm upgrade --install storefront-bff base/microservices/storefront-bff \
--namespace "$NAMESPACE" --create-namespace \
--set global.environment="$ENVIRONMENT" \
--set global.storefrontHost="$STOREFRONT_HOST"

helm dependency build base/microservices/storefront-ui
helm upgrade --install storefront-ui base/microservices/storefront-ui \
--namespace "$NAMESPACE" --create-namespace \
--set global.storefrontHost="$STOREFRONT_HOST"

sleep 60

helm upgrade --install swagger-ui base/microservices/swagger-ui \
--namespace "$NAMESPACE" --create-namespace \
--set global.apiHost="$API_HOST" \
--set global.apiUrl="https://$API_HOST" \
--set ingress.host="$API_HOST"

sleep 20


# manual Search
#helm dependency build base/microservices/search
# helm upgrade --install search base/microservices/search --namespace "$NAMESPACE" --set backend.ingress.host="$API_HOST"

# Cập nhật config tổng khi có thay đổi values.yaml trong yas-configuration 
# helm upgrade --install yas-configuration base/microservices/yas-configuration --namespace "$NAMESPACE"

# for chart in {"cart","customer","inventory","location","media","order","payment","payment-paypal","product","promotion","rating","search","tax","recommendation","webhook","sampledata"} ; do
#     helm dependency build base/microservices/"$chart"
#     helm upgrade --install "$chart" base/microservices/"$chart" \
#     --namespace "$NAMESPACE" --create-namespace \
#     --set backend.ingress.host="$API_HOST"
#     sleep 60
# done

for chart in {"cart","customer","inventory","media","order","product","search","tax","sampledata"} ; do
    helm dependency build base/microservices/"$chart"
    helm upgrade --install "$chart" base/microservices/"$chart" \
    --namespace "$NAMESPACE" --create-namespace \
    --set global.environment="$ENVIRONMENT" \
    --set backend.ingress.host="$API_HOST"
    sleep 60
done
