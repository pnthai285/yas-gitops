# Cloudflare Tunnel notes

This repo runs `cloudflared` as an in-cluster connector. The Kubernetes
deployment reads a tunnel token from a namespace-scoped SealedSecret, and
Cloudflare public hostname routes are managed in the Cloudflare Zero Trust
Dashboard.

Do not commit tunnel tokens, `credentials.json`, or plaintext token files.

## GitOps resources

```text
base/infrastructure/cloudflared/
overlays/dev/cloudflared/
overlays/stage/cloudflared/
sealed-secrets/cloudflared/dev/
sealed-secrets/cloudflared/stage/
```

The dev connector is enabled with 2 replicas.

The stage connector skeleton is present but currently scaled to 0 replicas until
a separate stage tunnel token is sealed into
`sealed-secrets/cloudflared/stage/cloudflared-token.yaml`.

The current dev connector token starts tunnel ID
`1f92d31d-8009-414a-bf1f-b6992f00885f`. Public hostnames must be created on
that same tunnel. If a hostname is added to another tunnel or only to a
Cloudflare Access application, Cloudflare returns error 1033.

## Dashboard public hostname routes

Create these routes in Cloudflare Zero Trust -> Networks -> Tunnels -> the
target tunnel -> Public Hostnames.

Use `HTTP` for the service type unless noted otherwise.

Use `HTTPS` for ArgoCD and enable the Cloudflare origin option that skips TLS
verification, because `argocd-server` presents an internal service certificate.

### Dev tunnel

| Public hostname | Service URL |
| --- | --- |
| `identity-dev.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `api-dev.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `backoffice-dev.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `storefront-dev.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `kibana-dev.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `pgadmin-dev.yasdevops.dev` | `http://pgadmin.yas-dev.svc.cluster.local:80` |
| `pgoperator-dev.yasdevops.dev` | `http://postgres-operator.postgres-operator.svc.cluster.local:8080` |
| `argocd.yasdevops.dev` | `https://argocd-server.argocd.svc.cluster.local:443` |

### Stage tunnel

| Public hostname | Service URL |
| --- | --- |
| `identity-stage.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `api-stage.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `backoffice-stage.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `storefront-stage.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `kibana-stage.yasdevops.dev` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` |
| `pgadmin-stage.yasdevops.dev` | `http://pgadmin.yas-stage.svc.cluster.local:80` |
| `pgoperator-stage.yasdevops.dev` | `http://postgres-operator.postgres-operator.svc.cluster.local:8080` |

The current cluster does not expose an `akhq` service or a Grafana service.
Add their dashboard routes only after these services exist:

```bash
kubectl --kubeconfig ./.kube/k3s-config.yaml get svc -A | rg 'akhq|grafana'
```

Expected routes when those services are installed:

| Public hostname | Service URL |
| --- | --- |
| `akhq-dev.yasdevops.dev` | `http://akhq.<namespace>.svc.cluster.local:8080` |
| `akhq-stage.yasdevops.dev` | `http://akhq.<namespace>.svc.cluster.local:8080` |
| `grafana-dev.yasdevops.dev` | `http://<grafana-service>.observability.svc.cluster.local:80` |
| `grafana-stage.yasdevops.dev` | `http://<grafana-service>.observability.svc.cluster.local:80` |

## Create dashboard routes

For each public hostname:

1. Open Cloudflare Dashboard.
2. Go to Zero Trust -> Networks -> Tunnels.
3. Select the tunnel for the environment. For dev, use tunnel ID
   `1f92d31d-8009-414a-bf1f-b6992f00885f`.
4. Open Public Hostnames.
5. Add hostname, for example `backoffice-dev.yasdevops.dev`.
6. Set service type to `HTTP`, except `argocd.yasdevops.dev`, which uses `HTTPS`.
7. Set the service URL from the table above.
8. For `argocd.yasdevops.dev`, open Additional application settings -> TLS and enable `No TLS Verify`.
9. Save hostname.

Cloudflare will create the DNS CNAME automatically when the zone is managed by
Cloudflare. If it does not, add a proxied CNAME manually that points to the
tunnel target shown in the Dashboard.

## Error 1033 checklist

If Cloudflare returns 1033:

1. Confirm `kubectl get pods -n cloudflared-dev` shows 2 ready pods.
2. Confirm the route is under Zero Trust -> Networks -> Tunnels -> the dev
   tunnel with ID `1f92d31d-8009-414a-bf1f-b6992f00885f` -> Public Hostnames.
3. Confirm the hostname is not only configured as an Access Published
   Application.
4. Confirm the route service URL is exactly
   `https://argocd-server.argocd.svc.cluster.local:443` for ArgoCD.
5. Confirm ArgoCD route has `No TLS Verify` enabled.

## Validate

```bash
export KUBECONFIG=./.kube/k3s-config.yaml

kubectl get pods -n cloudflared-dev
kubectl logs -n cloudflared-dev -l app=cloudflared --tail=100

curl -I https://identity-dev.yasdevops.dev
curl -I https://api-dev.yasdevops.dev/swagger-ui
curl -I https://backoffice-dev.yasdevops.dev
curl -I https://storefront-dev.yasdevops.dev
curl -I https://kibana-dev.yasdevops.dev
curl -I https://argocd.yasdevops.dev
```

## Stage enablement

When you have a separate stage tunnel token, generate and validate the stage
SealedSecret, then change the stage cloudflared replica patch from 0 to 2:

```bash
export KUBECONFIG=./.kube/k3s-config.yaml
scripts/generate-cloudflared-sealed-secret.sh stage
kubeseal --validate < sealed-secrets/cloudflared/stage/cloudflared-token.yaml
```
