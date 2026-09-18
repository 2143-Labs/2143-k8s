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
| **labs.2143.me** | Storefront / coming-soon static site (nginx + ConfigMap) |

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
│   ├── wireguard-doks.yaml # WireGuard client into the home network
│   ├── deployment-labs-site.yaml  # labs.2143.me static site
│   ├── site/               # HTML/CSS source for labs.2143.me
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

## Static site — labs.2143.me

`labs.2143.me` is a plain static site: HTML and CSS in `base/site/`, served by
`nginxinc/nginx-unprivileged` with the files mounted from a ConfigMap.

| Piece | Where |
|---|---|
| Content | `base/site/` — `index.html`, `style.css`, `favicon.svg`, `robots.txt` |
| Workload | `base/deployment-labs-site.yaml` — `labs-site` Deployment + Service (80 → 8080) |
| Routing | `base/httproute.yaml` — `labs-site` HTTPRoute, hostname `labs.2143.me` |
| TLS | the existing `*.2143.me` wildcard listener and certificate — nothing to add |

The container runs unprivileged (uid 101, port 8080, read-only root, `/tmp` on
an emptyDir), so it needs no extra capabilities or writable root:

```bash
docker run --rm -it -p 8080:8080 \
  -v "$PWD/base/site:/usr/share/nginx/html:ro" \
  --read-only --tmpfs /tmp \
  nginxinc/nginx-unprivileged:1.31.6-alpine
```

**Adding a page or asset:** drop the file in `base/site/` and add it to the
`configMapGenerator` in `base/kustomization.yaml` — kustomize does not glob
generator inputs. The generated ConfigMap carries a content hash, so every
change rolls the pods on its own.

**Pointing `2143.me` here later:** move `2143.me` from `john2143-com-normal` to
the `labs-site` hostnames in `base/httproute.yaml`; the image host keeps every
other hostname it serves. The wildcard certificate already covers the apex, so
no Gateway or Certificate change is needed either way.

**When a build step is needed** (bundler, images, more than the ~1 MiB
ConfigMap ceiling): swap the ConfigMap for an image — a `Dockerfile.site` that
`COPY`s `base/site/` into nginx, built and pinned by a workflow like
`.github/workflows/tor.yml`, then referenced from the Deployment.

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

## Home network tunnel (WireGuard)

`base/wireguard-doks.yaml` runs one privileged `hostNetwork` pod that brings up
`wg0` and keeps a persistent tunnel to the home router (`wg-remote`,
`john2143.com:51820`). It exists so the cluster can reach hosts in the home
network without any of them being exposed to the internet:

| Property | Value |
|---|---|
| Tunnel addresses | node side `10.99.0.2/24`, router side `10.99.0.1/24` |
| Routed through it | `192.168.5.0/24`, `192.168.6.0/24`, `10.99.0.0/24` |
| Direction | the cluster dials the router; the DO cloud firewall allows no inbound UDP 51820, so the home side can never dial in |
| Private key | hand-applied Secret `wireguard-doks-key` (never in git — this repo is public) |
| Liveness | `persistent-keepalive 25`; the router peer is `2143-k8s cluster: postgres client + tunnel` |

Deliberately absent: any default route. `allowed-ips` lists home prefixes only,
so a broken tunnel cannot blackhole the node's own egress. The keepalive is
load-bearing, not cosmetic — the DO firewall is stateful, and the tunnel lives
only as long as the cluster keeps re-initiating it.

Verify:

```bash
kubectl -n default exec deploy/wireguard-doks -- wg show
kubectl -n default logs deploy/wireguard-doks --tail=5
```

## MongoDB access

MongoDB is **not** reachable from the internet. The `mongo-nodeport` Service
still publishes `32040`, but the DigitalOcean cloud firewall no longer opens
that port, and the `mongo.john2143.com` record and its DDNS CronJob are gone.

Clients reach it either from the home network or through the tunnel above:

| From | Address |
|---|---|
| Home LAN / home cluster | `10.99.0.2:32040` (over the tunnel) |
| In-cluster | `mongo:27017` (`server-uri`) |

The `worker-uri` key that home workloads consume is composed in
`workloads/secrets/default-mongo-creds.yaml` in the `argo` repo, pointing at the
tunnel address; the credentials still come from OpenBao. Reopening the public
path means re-adding the firewall rule and the DNS record — there is no
repo-side switch for it.

## CI/CD

### Tor relay — weekly rebuilds

[`.github/workflows/tor.yml`](.github/workflows/tor.yml) runs every Monday at 6am UTC
and on pushes to `Dockerfile.tor`:

1. Builds a fresh Tor image from `debian:stable-slim` + the Tor Project APT repo
   (builds with `--no-cache`, so `apt` always re-queries the Tor repo — cached
   layers are never reused)
2. Pushes to `ghcr.io/2143-labs/tor` with a run-number tag + `:latest`
3. Updates the pin in `overlays/prod/kustomization.yaml` (the root kustomization —
   `images:` declared in `base/` are ignored at render time) and commits

The workflow fails if the new tag doesn't land or the rendered output isn't
pinned to it. Flux sees the commit, syncs, and the `Recreate` strategy rolls out
a new pod.

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
