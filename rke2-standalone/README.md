# RKE2 Standalone Terraform Example

> **Example only — not for production.** This is a demonstration of the Durantic Terraform provider against throwaway dev01 machines. It ships a hardcoded join-token default and fixed hostnames, and is not hardened or supported for any real cluster. Use it as a reference, not a starting point you deploy as-is.

Creates an RKE2 standalone cluster on the five existing dev01 machines:

- Masters: `disposable-scaleway-01`, `disposable-scaleway-02`
- Workers: `disposable-scaleway-03`, `disposable-scaleway-04`, `disposable-scaleway-05`

The first master (`disposable-scaleway-01`) also receives the `cluster-init` role, which designates it as the single RKE2 cluster initializer. The remaining masters and all workers join afterwards.

This example creates the Durantic mesh network, VIP, secret, machine roles, and machine role assignments from scratch. It does not import role YAML from another repository, configure ArgoCD, or use the Cluster Wizard scenario API.

## What it creates

- **Mesh network** `rke2-standalone-mesh` — CIDR `10.60.0.0/24`, route reflector mode disabled.
- **VIP** `rke2-standalone-vip` — address `10.60.0.100`, assigned to both master machines, with a TCP health check against `:6443` (5s interval, 2 healthy / 3 unhealthy thresholds).
- **Secret** `RKE2_STANDALONE_DEV01_K8S_CLUSTER_TOKEN` — the shared RKE2 join token (from `var.k8s_cluster_token`).
- **Machine roles** (templates defined inline in `main.tf`):
  | Role | Merge priority | Image | Notes |
  |------|---------------|-------|-------|
  | `...-cluster-init` | 10 | — | Marks one master as the cluster initializer (assigned to the first master only) |
  | `...-rke2-server` | 100 | `ghcr.io/durantic/linux-ubuntu-25.10:rke2-server-1.35` | `requires_mesh = true`, bound to the VIP; renders `/etc/rancher/rke2/config.yaml` and TLS SANs |
  | `...-rke2-agent` | 100 | `ghcr.io/durantic/linux-ubuntu-25.10:rke2-agent-1.35` | `requires_mesh = true`; workers join `SERVER_URL` = the VIP address |
  | `...-ssh-keys` | 20 | — | Imports GitHub SSH keys on every machine |
- **Machine deployments** — assign mesh membership and roles:
  - Masters: `ssh-keys` + `rke2-server` (plus `cluster-init` on the first master).
  - Workers: `ssh-keys` + `rke2-agent`.
  - Both carry `force_provision = "v1"` — bump this string to force re-provisioning (e.g. after a base image update).

## Prerequisites

Build and install the local provider first:

```bash
cd /home/ubuntu/git/durantic/terraform-provider
make install
```

Use a Terraform dev override that points at the installed provider binary directory, for example:

```hcl
provider_installation {
  dev_overrides {
    "registry.durantic.io/durantic/durantic" = "/home/ubuntu/go/bin"
  }

  direct {}
}
```

Export credentials for dev01:

```bash
export DURANTIC_ENDPOINT="https://api.dev01.durantic.dev"
export DURANTIC_API_TOKEN="..."
```

## Variables

- `k8s_cluster_token` — shared RKE2 cluster join token. Has a default in `variables.tf`, but for a real cluster override it with your own:
  ```bash
  export TF_VAR_k8s_cluster_token="$(openssl rand -hex 32)"
  ```
- `ssh_github_users` — GitHub usernames whose public SSH keys are imported on every machine. Defaults to:
  - `EvgeniyS-Planhat`
  - `ivand6c`
  - `vilorij`

  Override with:
  ```bash
  export TF_VAR_ssh_github_users='["octocat","another-user"]'
  ```

## Apply

```bash
cd /home/ubuntu/git/durantic/durantic-tf-examples/rke2-standalone
terraform plan
terraform apply
```

After apply, provision the machines manually in this order — the cluster-init master (`disposable-scaleway-01`) must come up first:

1. `disposable-scaleway-01` (cluster initializer)
2. `disposable-scaleway-02`
3. `disposable-scaleway-03`
4. `disposable-scaleway-04`
5. `disposable-scaleway-05`

Provisioning is intentionally manual; this example only manages desired Durantic configuration.

## Outputs

`outputs.tf` exposes:

- `cluster_name` — the local cluster name (`rke2-standalone`).
- `k8s_vip` — the VIP address (`10.60.0.100`).
- `init_master` — hostname, UUID, and mesh IP of the cluster-init master.
- `masters` — per-master UUID, mesh IP, and discovered public IPs.
- `workers` — per-worker UUID and mesh IP.
- `roles` — name and UUID of each created machine role.

## Notes

- No `GATEWAY_PUBLIC_IP` variable is created. The RKE2 server template includes each master's discovered public IPs in `tls-san`, alongside every server node's mesh IP and hostname and (when set) the VIP address.
- The mesh-internal VIP is assigned to the master machines. Workers join through it on port `9345`; the VIP health check itself targets the Kubernetes API on `:6443`.
- Role templates are defined directly in `main.tf` and use this example's account-owned role and secret names.
