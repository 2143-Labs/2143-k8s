# 2143-k8s

FluxCD-managed Kubernetes cluster running on DigitalOcean. All infrastructure
is defined as code — Git is the source of truth, FluxCD handles reconciliation.

## What's deployed

| Service | Description |
|---|---|
| **john2143.com** | Image host (ghcr.io/john2143/john2143.com) |
| **Tor middle relay** | `2143Me` — non-exit relay on port 30901 |
| **Tailscale exit node** | VPN exit for tailnet |
| **DERP relay** | Tailscale DERP server |
| **OpenFrontPro** | API + Discord bot |

## Directory structure

```
.
├── base/                   # Shared Kustomize base layer
│   ├── deployments.yaml    # john2143-com, tailscale-exit
│   ├── deployment-tor.yaml
│   ├── deployments-derp.yaml
│   ├── deployments-openfrontpro.yaml
│   ├── deployments-openfront-discordbot.yaml
│   ├── gateway.yaml        # nginx-gateway-fabric Gateway
│   ├── httproute.yaml
│   ├── tcproute.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── prod/               # Production overlay (patches, certs, PVCs, HPA)
│   └── dev/                # Dev overlay
├── clusters/prod/flux-system/  # FluxCD bootstrap + resources
│   ├── gotk-components.yaml    # Flux controllers (source, kustomize, notification)
│   ├── gitrepository.yaml      # Git source definition
│   ├── kustomization-prod.yaml # Syncs overlays/prod every 1m
│   ├── notification-provider.yaml  # GitHub commit status provider
│   └── notification-alert.yaml     # Alerts on prod Kustomization events
├── Dockerfile.tor          # Tor relay image
├── Dockerfile.derper       # DERP relay image
└── .github/workflows/      # CI: image builds, deploy status
```

## GitOps flow

```
Push to main  →  FluxCD sources the repo (1m interval)
              →  Kustomize builds overlays/prod
              →  Applies to cluster
              →  Health checks: john2143-com, tor-middle, tailscale-exit
```

Every commit to `main` gets a `Flux/prod` status on GitHub — pending during
reconciliation, then success or failure with the reconciliation message.

## Making changes

PR and merge to `main`. Flux picks it up within 60 seconds. No `kubectl apply`
needed — the cluster converges to match the repo.

To apply manually (rare):
```bash
kubectl apply -k overlays/prod/
```

## CI/CD

### Tor relay — weekly rebuilds

[`.github/workflows/tor.yml`](.github/workflows/tor.yml) runs every Monday at 6am UTC
and on pushes to `Dockerfile.tor`:

1. Builds a fresh Tor image from `debian:stable-slim` + the Tor Project APT repo
2. Pushes to `ghcr.io/2143-labs/tor` with a run-number tag + `:latest`
3. Updates `base/kustomization.yaml` with the new pinned tag and commits

Flux sees the commit, syncs, and the `Recreate` strategy rolls out a new pod.

### DERP relay

[`.github/workflows/derper.yml`](.github/workflows/derper.yml) builds on pushes to
`Dockerfile.derper`. Pushes `ghcr.io/2143-labs/derper:latest`.

## Tor middle relay

| Setting | Value |
|---|---|
| Nickname | `2143Me` |
| Contact | `tor@2143.me` |
| ORPort | `30901` (hostNetwork NodePort) |
| Bandwidth | 60 MBit rate / 120 MBit burst |
| Exit policy | `reject *:*` (middle relay only) |

Config: `base/deployment-tor.yaml` + `base/kustomization.yaml`

Image: `ghcr.io/2143-labs/tor` — built from `Dockerfile.tor`

Relay status: https://metrics.torproject.org/rs.html#details/6E00E3C03DBDF4FE99F0324337954D458F13DB9A

### Verify

```bash
kubectl get pods -l app=tor-middle
kubectl logs -l app=tor-middle --tail=5
```

## Bootstrap

To bootstrap FluxCD onto a cluster:
```bash
flux install --components=source-controller,kustomize-controller,notification-controller
kubectl apply -k clusters/prod/flux-system/
```

The cluster must first have nginx-gateway-fabric and cert-manager installed.
