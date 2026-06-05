# NodeJS + MongoDB Terraform Example

> **Example only — not for production.** This demonstrates the Durantic Terraform
> provider by deploying a tiny 3-tier NodeJS app across three existing machines. It ships
> a hardcoded MongoDB password default, single-machine VIPs (no HA), and `no-auth` app
> semantics. Use it as a reference, not a starting point you deploy as-is.

Deploys a simple **frontend + backend + MongoDB** demo over a Durantic mesh network with
one VirtualIP:

- **Frontend** (the *Worker*) — the only public-facing tier. Serves a one-page UI and
  reverse-proxies `/api` to the backend over the mesh.
- **Backend** (the *Render* tier) — generates a PDF from user text (random font) and stores
  it in MongoDB. Reached through the **backend VIP** (`10.61.0.100`).
- **MongoDB** — stores the PDFs. Reached directly on its **mesh IP** (discovered by the
  backend from the mesh peers).

This example creates the Durantic mesh network, a VIP, a secret, machine roles, and
machine deployments from scratch. It does not import role YAML from another repo, configure
ArgoCD, or use the Cluster Wizard scenario API. Both the **app code** and the **Terraform**
live in this folder.

## The app

A user types text (≤ 400 characters) and clicks **Generate**. The backend renders a PDF
using a random PDFKit standard font, stores the bytes in MongoDB, and the document appears
in a shared list anyone can download. No auth, no accounts — every client shares the same
documents and can upload/download simultaneously.

| Tier | Endpoint(s) | Talks to |
|------|-------------|----------|
| Frontend (`app/frontend`) | `:80` UI, proxies `/api/*` | backend VIP `:3000` |
| Backend (`app/backend`) | `POST /api/generate`, `GET /api/documents`, `GET /api/documents/:id`, `GET /healthz` | MongoDB mesh IP `:27017` |
| MongoDB (`app/mongodb`) | `:27017` (mesh IP) | — |

## Architecture

```
   user (browser)
        │  http  (public IP, :80)
        ▼
  ┌───────────┐
  │ Frontend  │  Worker — public + mesh IP, proxies /api
  └─────┬─────┘
        │  mesh
        ▼
   VIP Render (10.61.0.100)  ──►  ┌──────────┐
                                  │ Backend  │  Render — PDF generator
                                  └────┬─────┘
                                       │  mesh (mongo peer mesh IP)
                                       ▼
                                  ┌──────────┐
                                  │ MongoDB  │  :27017 on its mesh IP
                                  └──────────┘
```

Functional traffic path: **User → Frontend(:80) → VIP Render(:3000) → Backend → MongoDB(:27017, mesh IP).**
The backend VIP lives inside the Durantic mesh and is reachable mesh-wide; it backs a single
machine here to showcase the `durantic_vip` resource, not for HA. The backend reaches
MongoDB directly on the mongo machine's mesh IP, which it discovers at provision time from
the `peers` context (the peer carrying the `...-mongodb` role).

## What it creates

- **Mesh network** `nodejs-app-mongodb-mesh` — CIDR `10.61.0.0/24`, route reflector disabled.
- **VIP**:
  | VIP | Address | Backs | Health check |
  |-----|---------|-------|--------------|
  | `...-backend-vip` (Render) | `10.61.0.100` | backend machine | TCP `:3000` |
- **Secret** `NODEJS_APP_MONGODB_PASSWORD` — the MongoDB root password (from `var.mongodb_password`).
- **Machine roles** (templates inline in `main.tf`):
  | Role | Merge priority | Image | Notes |
  |------|---------------|-------|-------|
  | `...-ssh-keys` | 20 | — | Imports GitHub SSH keys on every machine |
  | `...-mongodb` | 100 | `:mongodb` | `requires_mesh`; writes `/etc/durantic/mongodb.env`, starts native `mongod` bound to its mesh IP |
  | `...-backend` | 100 | `:backend` | `requires_mesh`, bound to backend VIP; writes `/etc/durantic/backend.env` with `MONGODB_URL` → mongo peer mesh IP (discovered via `peers`) |
  | `...-frontend` | 100 | `:frontend` | `requires_mesh`; writes `/etc/durantic/frontend.env` with `BACKEND_URL` → backend VIP |
- **Machine deployments** — one per tier, each carrying `ssh-keys` + its tier role, mesh
  membership, and `force_provision = "v1"` (bump to force re-provisioning).

## Boot images

The app ships as **Durantic boot images** — complete-system OCI images built `FROM
ghcr.io/durantic/linux-ubuntu-25.10:latest`, the same pattern as the official RKE2 images
(`official-roles/images/Dockerfile.ubuntu-25.10-rke2-*`). Each image bakes in the runtime,
the app, a systemd unit, and a bootstrap script. The machine role renders an env file at
boot (`/etc/durantic/<tier>.env`) and `runcmd` starts the service.

| Image | Built from | Contains |
|-------|-----------|----------|
| `app/frontend/Dockerfile` | base + Node.js 20 | Express server + `public/index.html`, `frontend.service` |
| `app/backend/Dockerfile` | base + Node.js 20 | Express + `mongodb` + `pdfkit`, `backend.service` |
| `app/mongodb/Dockerfile` | base + `mongodb-org` | native `mongod`, configured + started by `mongodb-bootstrap.sh` |

> MongoDB is installed natively (`mongodb-org` 8.0). Ubuntu 25.10 ("questing") has no MongoDB
> apt packages, so the image uses MongoDB's **noble** (24.04 LTS) repo, which is ABI-compatible
> with the 25.10 base. At boot, `mongodb-bootstrap.sh` writes `/etc/mongod.conf` (bound to
> localhost + the mesh IP, auth enabled), starts `mongod`, and creates the root user via the
> localhost exception.

### Build & push the boot images

```bash
cd /home/ubuntu/git/durantic/durantic-tf-examples/nodejs-app-mongodb

docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:frontend -f app/frontend/Dockerfile app/frontend
docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:backend  -f app/backend/Dockerfile  app/backend
docker build -t ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb  -f app/mongodb/Dockerfile  app/mongodb

docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:frontend
docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:backend
docker push ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb
```

The boot images are published to a repo dedicated to this example
(`ghcr.io/dev1l/dur-example-nodejs-app-mongodb`); only the `FROM` base
(`ghcr.io/durantic/linux-ubuntu-25.10:latest`) comes from the Durantic platform registry.

After pushing, the `Image` records must exist in the controlplane DB before the role can
reference them. Register them the same way the RKE2 images are registered — see
`official-roles/images/README.md` ("Register images in the controlplane"); substitute the
three `ghcr.io/dev1l/dur-example-nodejs-app-mongodb` URLs above.

### Run the app locally (no Durantic needed)

A quick sanity check of the app itself:

```bash
# 1. MongoDB
docker run -d --name demo-mongo -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=root -e MONGO_INITDB_ROOT_PASSWORD=testpw mongo:8

# 2. Backend
cd app/backend && npm install
MONGODB_URL="mongodb://root:testpw@127.0.0.1:27017/?authSource=admin" PORT=3000 node server.js

# 3. Frontend (new shell)
cd app/frontend && npm install
BACKEND_URL="http://127.0.0.1:3000" PORT=8080 node server.js

# Open http://localhost:8080
```

## Prerequisites

Build and install the local provider first:

```bash
cd /home/ubuntu/git/durantic/terraform-provider
make install
```

Use a Terraform dev override that points at the installed provider binary directory:

```hcl
provider_installation {
  dev_overrides {
    "registry.durantic.io/durantic/durantic" = "/home/ubuntu/go/bin"
  }

  direct {}
}
```

Export credentials:

```bash
export DURANTIC_ENDPOINT="https://api.dev01.durantic.dev"
export DURANTIC_API_TOKEN="..."
```

## Variables

- `frontend_hostname`, `backend_hostname`, `mongodb_hostname` — hostnames of three existing
  Durantic machines (one per tier). Defaults are `demo-*` placeholders; set your own:
  ```bash
  export TF_VAR_frontend_hostname="my-frontend-host"
  export TF_VAR_backend_hostname="my-backend-host"
  export TF_VAR_mongodb_hostname="my-mongodb-host"
  ```
- `mongodb_password` — MongoDB root password. Has a dev default; override for anything real:
  ```bash
  export TF_VAR_mongodb_password="$(openssl rand -hex 24)"
  ```
- `ssh_github_users` — GitHub usernames whose public SSH keys are imported on every machine.
- `frontend_image` / `backend_image` / `mongodb_image` — boot image URLs (default to the
  `ghcr.io/dev1l/dur-example-nodejs-app-mongodb` tags above).

## Apply

```bash
cd /home/ubuntu/git/durantic/durantic-tf-examples/nodejs-app-mongodb
terraform init
terraform plan
terraform apply
```

After apply, provision the machines manually in this order — the data tier first so the
backend and frontend find their dependencies on boot:

1. **mongodb** machine
2. **backend** machine
3. **frontend** machine

Provisioning is intentionally manual; this example only manages desired Durantic config.

## Use it

Open the `app_url` output (the frontend's public IP) in a browser, type some text, and click
**Generate**. The PDF appears in the shared list below and can be downloaded by anyone.

## Outputs

`outputs.tf` exposes:

- `app_url` — open this in a browser (frontend's first discovered public IP).
- `backend_vip` — the backend VIP address.
- `frontend` / `backend` / `mongodb` — per-tier hostname, UUID, mesh IP, public IPs.
- `roles` — name and UUID of each created machine role.

## Notes

- The backend reaches MongoDB directly on the mongo machine's mesh IP, discovered at provision
  time from the `peers` context (the peer carrying the `...-mongodb` role) — the same
  peer-discovery technique the `rke2-standalone` example uses to find server nodes. The mesh
  IP isn't known at plan time, so it can't be a static Terraform value.
- The single backend VIP is intentional (it demonstrates the `durantic_vip` resource), not HA.
  Because a Durantic VIP is a floating address local to the holding machine, a service must
  bind to all interfaces (`0.0.0.0`) to be reachable on it — the frontend and backend Node
  servers do. `mongod` binds localhost + its own mesh IP (not a VIP), and the backend reaches
  it directly on that mesh IP.
- Reuses the `ssh-keys` role and the `force_provision` bump idiom from `rke2-standalone`.
