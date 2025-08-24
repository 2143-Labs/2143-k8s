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

# ArgoCD GitOps

This repository is now configured to use ArgoCD for GitOps-based deployment. See the [argocd/README.md](argocd/README.md) file for detailed instructions.

## Quick Start

```bash
# Create the ArgoCD namespace
kubectl create namespace argocd

# Configure SSH access first - edit argocd/repos/github-ssh-secret.yaml
# Then deploy the key, project, and root application
kubectl apply -f argocd/repos/github-ssh-secret.yaml
kubectl apply -f argocd/projects/prod-project.yaml
kubectl apply -f argocd/apps/root.yaml

# Access the ArgoCD UI
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then visit https://localhost:8080 in your browser (username: admin).
