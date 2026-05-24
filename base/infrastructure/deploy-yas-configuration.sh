
set -x

# Auto restart when change configmap or secret
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

helm dependency build base/microservices/yas-configuration
helm upgrade --install yas-configuration base/microservices/yas-configuration \
--namespace yas --create-namespace

