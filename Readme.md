# Example
`curl -k https://2143.christmas/tea/1234`
## Kubernetes Deployment with loadbalancer:
![Kubernetes Deployment](http://2143.moe/f/uZsk.png)

# About each file
### `coffee.yaml`:
This defines two demo apps and services: `tea` and `coffee`
### `gateway.yaml`:
This defines the Gateway: `cafe`. A corresponding pod will be created in the
`nginx-gateway` namespace.

This gateway is deployed into the default namespace. Apps can only communicate
within their own namespace by default. This can be changed with either a
`ReferenceGrant` or by setting `allowedRoutes` to `All`.

This file also defines a `ReferenceGrant` that allows the `cafe` gateway to
read Secrets from the `certificate` namespace.
### `httproute.yaml`:
This file defines two `HTTPRoute`s in the `cafe` gateway. It routes `/tea` to the `tea` service
and `/coffee` to the `coffee` service.

It also defines an HTTP -> HTTPS redirect.
### `nginx-crds.yaml`:
https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.4.0/deploy/crds.yaml
### `nginx-fabric.yaml`:
https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.4.0/deploy/default/deploy.yaml
### `certificates.yaml`:
This is just a test certificate, replace the secret with your own

# Installation
## Create Cluster
```bash
kind create cluster --name net
```

## Install CRDs
```bash
kubectl kustomize "https://github.com/nginxinc/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.4.0" | kubectl apply -f -
```

## Install cert-manager w/ api gateway
```bash
cmctl x install
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager \
        --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
        --set config.kind="ControllerConfiguration" \
        --set config.enableGatewayAPI=tru
```

## Deploy everything here
```bash
kubectl apply -f .
```

## Test
```bash
curl -k https://2143.christmas/tea/1234
curl -k https://2143.christmas/coffee/asdf
```

# Cert-manager

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
```

## Tor Middle Relay — deployed via FluxCD

A Tor middle relay (`2143Me`) runs as a Kubernetes deployment managed by
FluxCD. It listens on port `30901` (NodePort via hostNetwork).

## Configuration

Config is in `base/deployment-tor.yaml` + `base/kustomization.yaml`:

| Setting | Value |
|---|---|
| Nickname | `2143Me` |
| Contact | `tor@2143.me` |
| ORPort | `30901` |
| Bandwidth | 60 MBit rate / 120 MBit burst |
| Exit policy | `reject *:*` (middle relay, not exit) |

## Image

Built from `Dockerfile.tor` — a minimal `debian:stable-slim` image with Tor
installed from the official [Tor Project APT repo](https://deb.torproject.org/).

Published to `ghcr.io/2143-labs/tor`.

## Auto-Updates

A [GitHub Actions workflow](.github/workflows/tor.yml) rebuilds the image every
**Monday at 6am UTC** (and on pushes to `Dockerfile.tor`). Each build:

1. Pulls the latest Tor from `deb.torproject.org`
2. Pushes the image to ghcr with a unique tag (`github.run_number`) and `:latest`
3. Updates `base/kustomization.yaml` with the pinned tag and commits

Flux detects the kustomization change, syncs, and the `Recreate` strategy
rolls out a new pod — no manual involvement needed.

## Verify

```bash
kubectl get pods -l app=tor-middle
kubectl logs -l app=tor-middle --tail=5
```

Relay status: https://metrics.torproject.org/rs.html#details/6E00E3C03DBDF4FE99F0324337954D458F13DB9A

## Deployment

All cluster infrastructure is defined in `clusters/prod/flux-system/` and
applied by FluxCD's kustomize-controller. The entrypoint is a bootstrap
kustomization that deploys Flux controllers, the Git source, and the prod
sync rule.
