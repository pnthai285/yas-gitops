# Cloudflare Tunnel notes

This repo is prepared to expose YAS through a Cloudflare Tunnel without changing
application charts.

Recommended tunnel routing:

```yaml
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/creds/credentials.json

ingress:
  - hostname: identity-dev.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: api-dev.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: backoffice-dev.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: storefront-dev.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: identity-stage.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: api-stage.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: backoffice-stage.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - hostname: storefront-stage.yasdevops.dev
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - service: http_status:404
```

Before switching public traffic to Cloudflare HTTPS:

1. Set `global.identityScheme: https` and `global.identityUrl:
   https://identity-<env>.yasdevops.dev` in the target overlay values.
2. Set `identityScheme: https` in `argocd/workloads-appset.yaml` for the
   target environment so Keycloak publishes the HTTPS issuer.
3. Disable or remove `argocd/platform-coredns-custom.yaml` if pods should
   resolve public hostnames through Cloudflare instead of the in-cluster
   ingress-nginx service.
4. Keep the ingress-nginx service as `ClusterIP`; `cloudflared` connects to it
   from inside the cluster.
