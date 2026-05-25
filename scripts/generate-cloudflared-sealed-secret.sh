#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${YAS_KUBECONFIG:-${KUBECONFIG:-./.kube/k3s-config.yaml}}"
KUBESEAL_CONTROLLER_NAME="${KUBESEAL_CONTROLLER_NAME:-sealed-secrets-controller}"
KUBESEAL_CONTROLLER_NAMESPACE="${KUBESEAL_CONTROLLER_NAMESPACE:-kube-system}"

usage() {
  cat <<'USAGE'
Usage:
  CLOUDFLARED_TUNNEL_TOKEN='<token>' scripts/generate-cloudflared-sealed-secret.sh dev
  CLOUDFLARED_TUNNEL_TOKEN='<token>' scripts/generate-cloudflared-sealed-secret.sh stage

Each environment must use its own Cloudflare Tunnel token.
The plaintext token must not be committed.
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

ENVIRONMENT="${1:-}"
case "$ENVIRONMENT" in
  dev)
    NAMESPACE="cloudflared-dev"
    OUTPUT_DIR="sealed-secrets/cloudflared/dev"
    ;;
  stage)
    NAMESPACE="cloudflared-stage"
    OUTPUT_DIR="sealed-secrets/cloudflared/stage"
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

if [ -z "${CLOUDFLARED_TUNNEL_TOKEN:-}" ]; then
  echo "Missing CLOUDFLARED_TUNNEL_TOKEN" >&2
  exit 1
fi

require_command kubectl
require_command kubeseal

mkdir -p "$OUTPUT_DIR"

kubectl create secret generic cloudflared-token \
  --namespace "$NAMESPACE" \
  --from-literal="token=${CLOUDFLARED_TUNNEL_TOKEN}" \
  --dry-run=client \
  -o yaml \
  | kubeseal \
      --controller-name "$KUBESEAL_CONTROLLER_NAME" \
      --controller-namespace "$KUBESEAL_CONTROLLER_NAMESPACE" \
      --scope namespace-wide \
      --format yaml > "${OUTPUT_DIR}/cloudflared-token.yaml"

kubeseal \
  --controller-name "$KUBESEAL_CONTROLLER_NAME" \
  --controller-namespace "$KUBESEAL_CONTROLLER_NAMESPACE" \
  --validate < "${OUTPUT_DIR}/cloudflared-token.yaml"

echo "Generated ${OUTPUT_DIR}/cloudflared-token.yaml"
