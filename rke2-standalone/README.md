# RKE2 Standalone Terraform Example

Creates an RKE2 standalone cluster on the five existing dev01 machines:

- Masters: `disposable-scaleway-01`, `disposable-scaleway-02`
- Workers: `disposable-scaleway-03`, `disposable-scaleway-04`, `disposable-scaleway-05`

This example creates the Durantic mesh network, VIP, secret, machine roles, SSH keys role, and machine role assignments from scratch. The VIP is assigned to the two master machines. It does not import role YAML from another repository, configure ArgoCD, or use the Cluster Wizard scenario API.

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
export TF_VAR_k8s_cluster_token="$(openssl rand -hex 32)"
```

The example imports GitHub SSH keys for these users by default:

- `EvgeniyS-Planhat`
- `ivand6c`
- `vilorij`

Override them with:

```bash
export TF_VAR_ssh_github_users='["octocat","another-user"]'
```

## Apply

```bash
cd /home/ubuntu/git/durantic/durantic-tf-examples/rke2-standalone
terraform plan
terraform apply -parallelism=1
```

`-parallelism=1` is required until mesh WireGuard IP allocation is made atomic in the controlplane API. Without it, concurrent machine assignments can race and the API may try to assign the same mesh IP to multiple machines.

After apply, provision the machines manually in this order:

1. `disposable-scaleway-01`
2. `disposable-scaleway-02`
3. `disposable-scaleway-03`
4. `disposable-scaleway-04`
5. `disposable-scaleway-05`

Provisioning is intentionally manual; this example only manages desired Durantic configuration.

## Notes

- No `GATEWAY_PUBLIC_IP` variable is created. The RKE2 server template will include each master's discovered public IPs in `tls-san`.
- The mesh-internal VIP is assigned to the master machines. Workers join through it on port `9345`.
- Role templates are defined directly in `main.tf` and use this example's account-owned role and secret names.
