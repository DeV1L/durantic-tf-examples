# durantic-tf-examples

Worked examples for the [**Durantic** Terraform provider](https://registry.terraform.io/providers/durantic/durantic/latest),
published on the public Terraform Registry as [`durantic/durantic`](https://registry.terraform.io/providers/durantic/durantic/latest).

Each directory is a self-contained Terraform configuration that manages Durantic platform
resources — mesh networks, machine roles, VIPs, secrets, registry credentials — and drives
a real workload onto Durantic machines. Read each example's own `README.md` for the full
walkthrough.

## Using the provider

The provider downloads automatically on `terraform init`. Declare it in your configuration:

```hcl
terraform {
  required_providers {
    durantic = {
      source  = "durantic/durantic"
      version = "~> 1.0"
    }
  }
}

provider "durantic" {
  # endpoint  read from DURANTIC_ENDPOINT  (default: https://api.demo.durantic.dev)
  # api_token read from DURANTIC_API_TOKEN (required)
}
```

Then export credentials and run Terraform:

```bash
export DURANTIC_ENDPOINT="https://api.demo.durantic.dev"
export DURANTIC_API_TOKEN="dur_..."

terraform init
terraform plan
terraform apply
```

See the [provider documentation](https://registry.terraform.io/providers/durantic/durantic/latest/docs)
for the full schema (resources, data sources, and the provider configuration).

## Examples

| Example | What it builds |
|---------|----------------|
| [`nodejs-app-mongodb`](nodejs-app-mongodb) | A three-tier Node.js + MongoDB app running directly on three bare-metal Durantic machines (frontend / backend / native `mongod`), wired together over a mesh network and a backend VIP. |
| [`k3s-standalone-argocd`](k3s-standalone-argocd) | The Kubernetes counterpart of `nodejs-app-mongodb`: provisions one machine into a single-node k3s cluster with ArgoCD that deploys the same app from a GitOps repo. |
| [`rke2-standalone`](rke2-standalone) | A multi-node RKE2 cluster (two masters + three workers) with an HA VIP, built entirely from provider resources — mesh network, VIP, secret, machine roles, and deployments. |

> These are reference examples, not production-ready modules. They use throwaway hostnames,
> hardcoded defaults, and dev credentials — read each one before adapting it.
