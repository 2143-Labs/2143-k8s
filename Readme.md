# Install 2

## Create Cluster
kind create cluster --name net

## Install CRDs
kubectl kustomize "https://github.com/nginxinc/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.4.0" | kubectl apply -f -
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.4.0/deploy/crds.yaml

## Deploy NGINX Gateway Fabric
https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.4.0/deploy/default/deploy.yaml

## Deploy everything here
kubectl apply -f .

## Test
kubectl exec -it -n nginx-gateway pods/nginx-gateway-bccf868b6-7w9jt -c nginx -- /bin/sh
curl -k --resolve cafe.example.com:443:127.0.0.1 https://cafe.example.com/tea/1234
curl -k --resolve cafe.example.com:443:127.0.0.1 https://cafe.example.com/coffee/asdf

