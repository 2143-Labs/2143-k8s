# About each file
## nginx-crds.yaml:
https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.4.0/deploy/crds.yaml
## nginx-fabric.yaml:
https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.4.0/deploy/default/deploy.yaml
## certificates.yaml:
This is just a test certificate, replace the secret with your own
## coffee.yaml:
This defines two demo apps and services: tea and coffee
## gateway.yaml:
This defines the Gateway: `cafe`. A corresponding pod will be created in the
`nginx-gateway` namespace.

This gateway is deployed into the default namespace. Apps can only communicate
within their own namespace by default. This can be changed with either a
`ReferenceGrant` or by setting `allowedRoutes` to `All`.

This file also defines a `ReferenceGrant` that allows the `cafe` gateway to
read Secrets from the `certificate` namespace.
## httproute.yaml:
This file defines two `HTTPRoute`s in `cafe` gateway. It routes `/tea` to the `tea` service
and `/coffee` to the `coffee` service.

It also defines an HTTP -> HTTPS redirect.

# Installation
## Create Cluster
kind create cluster --name net

## Install CRDs
kubectl kustomize "https://github.com/nginxinc/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.4.0" | kubectl apply -f -

## Deploy everything here
kubectl apply -f .

## Test
curl -k https://2143.christmas/tea/1234
curl -k https://2143.christmas/coffee/asdf
