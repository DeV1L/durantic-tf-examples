# k3s-standalone-argocd

Provisions **one** existing Durantic machine into a **single-node k3s cluster with ArgoCD**
(standalone — no gateway, no VIP) and lets ArgoCD deploy a three-tier Node.js + MongoDB
app from a GitOps repo.

It is the Kubernetes counterpart of [`nodejs-app-mongodb`](../nodejs-app-mongodb) (which
runs the same app directly on three bare-metal machines): here the app runs as Kubernetes
workloads, delivered by ArgoCD.

## What it builds

- A custom `durantic_machine_role` modeled on the official **`k3s-server`** standalone
  pattern: boots the plain `linux-ubuntu-25.10:latest` base image and **installs k3s at
  runtime** via cloud-init (no special baked image, no gateway).
- k3s auto-deploys **ArgoCD** from a bundled HelmChart, then the role creates an
  **app-of-apps** `Application` pointing at the repo below.
- A fresh mesh network (`10.62.0.0/24`) and uniquely-named secrets/variables
  (`K3S_STANDALONE_ARGOCD_*`) — it never reuses anything already in the account.
- The node's own public IP serves both the app (Traefik ingress, `:80`) and the ArgoCD UI
  (NodePort, `:30080`). The k8s API is published on the public IP automatically.

ArgoCD deploys from **`github.com/DeV1L/argocd-example-apps`**, branch `irrisketch-demo`,
path `apps/` → `nodejs-app-mongodb/manifests` (frontend, backend, `mongo:8.0`).

## Prerequisites

- A registered, online Durantic machine to use as the node (default hostname
  `k3s-argocd-demo`).
- The two app images already pushed to `ghcr.io/dev1l/argocd-example-nodejs-app-mongodb`
  (`:frontend`, `:backend`). See the app repo's README for the manual build.
- Provider credentials in the environment:

```bash
export DURANTIC_ENDPOINT="https://api.demo.durantic.dev"
export DURANTIC_API_TOKEN="dur_..."
# ghcr.io PAT (read:packages) so the node can pull the private app images:
export TF_VAR_ghcr_token="ghp_..."
# Optional: a real cluster token
export TF_VAR_k3s_cluster_token="$(openssl rand -hex 32)"
```

## Usage

```bash
terraform init
terraform plan
terraform apply
```

`apply` re-provisions the node (it reboots into the base image and installs k3s + ArgoCD).
Provisioning the OS completes within the apply; k3s/ArgoCD/app come up shortly after over
the node's egress.

## Verify

```bash
terraform output            # app_url, argocd_url, password hint

# On the node:
ssh root@<node-public-ip> 'k3s kubectl get nodes'
ssh root@<node-public-ip> 'k3s kubectl get applications -n argocd'
ssh root@<node-public-ip> 'k3s kubectl get pods -n nodejs-app-mongodb'

# App (frontend -> backend -> mongo):
curl http://<node-public-ip>/
curl -X POST http://<node-public-ip>/api/generate \
  -H 'content-type: application/json' -d '{"text":"hello durantic"}'
curl http://<node-public-ip>/api/documents

# ArgoCD UI: http://<node-public-ip>:30080  (user: admin)
ssh root@<node-public-ip> \
  "k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

## Files

| File | Purpose |
|------|---------|
| `main.tf` | provider, mesh, secrets/variables, roles, deployment |
| `variables.tf` | node hostname, SSH users, ArgoCD repo/branch/path, tokens |
| `outputs.tf` | app/ArgoCD URLs, node info, provision status |
| `templates/k3s-argocd.cloud-init.yaml` | runtime k3s install + ArgoCD HelmChart + app-of-apps bootstrap + ghcr pull auth |
