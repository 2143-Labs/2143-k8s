# ArgoCD GitOps Setup

This directory contains the ArgoCD configuration for managing the 2143-k8s cluster using GitOps principles. ArgoCD is configured to deploy itself (self-bootstrap) and manage all production workloads.

## Directory Structure

```
argocd/
├── bootstrap/           # ArgoCD installation manifests
│   ├── 00-argocd-install.yaml  # Official ArgoCD installation
│   └── kustomization.yaml      # Kustomization for bootstrap
├── apps/                # ArgoCD Application manifests
│   ├── argocd.yaml     # Self-managing ArgoCD application
│   ├── prod.yaml       # Production overlay application
│   └── root.yaml       # App-of-Apps root application
├── projects/            # ArgoCD Project definitions
│   └── prod-project.yaml      # Production project with RBAC
├── repos/               # Repository access configuration
│   └── github-ssh-secret.yaml # SSH key for GitHub access (needs configuration)
└── README.md           # This file
```

## Prerequisites

1. **Kubernetes Cluster**: Ensure you have access to the `2143prod` cluster
2. **SSH Key**: A deploy key or SSH key with read access to `git@github.com:John2143/2143-k8s.git`
3. **kubectl**: Configured to access the target cluster

## Initial Setup

### 1. Configure SSH Access

First, you need to configure the SSH secret for GitHub access:

1. Generate or use an existing SSH key that has read access to the repository
2. Base64 encode the private key:
   ```bash
   base64 -w 0 ~/.ssh/your-deploy-key
   ```
3. Edit `repos/github-ssh-secret.yaml` and replace `{{SSH_PRIVATE_KEY_BASE64}}` with the base64-encoded key

### 2. Bootstrap ArgoCD

Create the ArgoCD namespace and deploy the root application:

```bash
# Create the ArgoCD namespace
kubectl create namespace argocd

# Deploy the SSH secret first (after you've configured it)
kubectl apply -f repos/github-ssh-secret.yaml

# Deploy the AppProject
kubectl apply -f projects/prod-project.yaml

# Bootstrap ArgoCD using the root App-of-Apps pattern
kubectl apply -f apps/root.yaml
```

### 3. Wait for ArgoCD to Start

Monitor the ArgoCD deployment:

```bash
# Watch ArgoCD pods starting up
kubectl get pods -n argocd -w

# Check ArgoCD applications
kubectl get applications -n argocd
```

## Accessing ArgoCD UI

### Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Port Forward to ArgoCD Server

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then access the UI at: https://localhost:8080
- Username: `admin`
- Password: (from the secret above)

## How It Works

### Self-Bootstrap Pattern

1. **Initial Manual Step**: The `root.yaml` application is applied manually once
2. **ArgoCD Deploys Itself**: The root app deploys the `argocd.yaml` application, which points to `argocd/bootstrap/`
3. **ArgoCD Manages Itself**: From this point on, ArgoCD manages its own configuration and updates
4. **Production Deployment**: The `prod.yaml` application deploys the production overlay from `overlays/prod/`

### Applications Overview

| Application | Purpose | Source Path | Destination |
|-------------|---------|-------------|-------------|
| `root` | App-of-Apps that manages other applications | `argocd/apps/` | `argocd` namespace |
| `argocd` | ArgoCD self-management | `argocd/bootstrap/` | `argocd` namespace |
| `prod` | Production workloads | `overlays/prod/` | `default` namespace |

## Production Deployment

The `prod` application automatically deploys your production overlay which includes:

- john2143.com website
- OpenFront Pro services
- Discord bot
- Monitoring (Grafana, Prometheus)
- Gateway and routing configuration
- SSL certificates via cert-manager

## Troubleshooting

### Check Application Status

```bash
# List all applications
kubectl get applications -n argocd

# Get detailed status of an application
kubectl describe application prod -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Common Issues

1. **SSH Key Issues**: Make sure the SSH key is properly base64 encoded and has the correct permissions
2. **Sync Failures**: Check the ArgoCD UI for detailed sync error messages
3. **Resource Conflicts**: If resources already exist, ArgoCD may need manual intervention

### Reset ArgoCD

To completely reset ArgoCD (WARNING: This will delete all applications):

```bash
kubectl delete namespace argocd
```

Then repeat the bootstrap process.

## Security Notes

- The SSH private key in `repos/github-ssh-secret.yaml` should be treated as sensitive
- ArgoCD has admin access to the cluster through its service account
- The `prod` project restricts what repositories and destinations applications can use
- Consider rotating the SSH key periodically

## Maintenance

### Updating ArgoCD

ArgoCD updates itself automatically when you update the manifest in `bootstrap/00-argocd-install.yaml`. 
Simply update the file with a newer version and commit to Git.

### Adding New Applications

1. Create a new Application manifest in `apps/`
2. Add it to the appropriate project
3. Commit and push - ArgoCD will automatically deploy it

### Changing SSH Keys

1. Update the `repos/github-ssh-secret.yaml` file
2. Commit and push
3. ArgoCD will automatically update its repository access

## Repository Structure

This GitOps setup assumes the following repository structure:

```
/
├── base/              # Base Kubernetes manifests
├── overlays/
│   ├── dev/          # Development overlay (not managed by ArgoCD)
│   └── prod/         # Production overlay (managed by ArgoCD)
└── argocd/           # ArgoCD configuration (this directory)
```
