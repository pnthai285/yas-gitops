#!/bin/bash
set -x

# Auto restart when change configmap or secret
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

read -rd '' DOMAIN \
< <(yq -r '.domain' ./base/infrastructure/cluster-config.yaml)

helm dependency build base/microservices/backoffice-bff
helm upgrade --install backoffice-bff base/microservices/backoffice-bff \
--namespace yas --create-namespace \
--set backend.ingress.host="backoffice.$DOMAIN"

helm dependency build base/microservices/backoffice-ui
helm upgrade --install backoffice-ui base/microservices/backoffice-ui \
--namespace yas --create-namespace

sleep 60

helm dependency build base/microservices/storefront-bff
helm upgrade --install storefront-bff base/microservices/storefront-bff \
--namespace yas --create-namespace \
--set backend.ingress.host="storefront.$DOMAIN"

helm dependency build base/microservices/storefront-ui
helm upgrade --install storefront-ui base/microservices/storefront-ui \
--namespace yas --create-namespace

sleep 60

helm upgrade --install swagger-ui base/microservices/swagger-ui \
--namespace yas --create-namespace \
--set ingress.host="api.$DOMAIN"

sleep 20


# manual Search
#helm dependency build base/microservices/search
#helm upgrade --install search base/microservices/search --namespace yas --set backend.ingress.host="api.$DOMAIN"

# Cập nhật config tổng khi có thay đổi values.yaml trong yas-configuration 
# helm upgrade --install yas-configuration base/microservices/yas-configuration --namespace yas

# for chart in {"cart","customer","inventory","location","media","order","payment","payment-paypal","product","promotion","rating","search","tax","recommendation","webhook","sampledata"} ; do
#     helm dependency build base/microservices/"$chart"
#     helm upgrade --install "$chart" base/microservices/"$chart" \
#     --namespace yas --create-namespace \
#     --set backend.ingress.host="api.$DOMAIN"
#     sleep 60
# done

for chart in {"cart","customer","inventory","media","order","product","search","tax","sampledata"} ; do
    helm dependency build base/microservices/"$chart"
    helm upgrade --install "$chart" base/microservices/"$chart" \
    --namespace yas --create-namespace \
    --set backend.ingress.host="api.$DOMAIN"
    sleep 60
done