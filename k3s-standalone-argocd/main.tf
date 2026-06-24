terraform {
  required_providers {
    durantic = {
      source  = "durantic/durantic"
      version = "~> 1.0"
    }
  }
}

provider "durantic" {
  # api_token read from DURANTIC_API_TOKEN
  # endpoint read from DURANTIC_ENDPOINT, for example https://api.demo.durantic.dev
}

locals {
  cluster_name = "k3s-standalone-argocd"

  mesh_cidr = "10.62.0.0/24"

  k3s_role_name      = "k3s-standalone-argocd-server"
  ssh_keys_role_name = "k3s-standalone-argocd-ssh-keys"

  ssh_keys_template = <<-EOT
    #cloud-config
    #
    # Imports public SSH keys from GitHub.

    ssh_import_id:
    %{for user in var.ssh_github_users~}
      - gh:${user}
    %{endfor~}
  EOT
}

data "durantic_machine" "node" {
  hostname = var.node_hostname
}

# Baked single-node k3s + ArgoCD boot image (built from ../image, FROM the official
# Ubuntu base). k3s + the ArgoCD HelmChart manifest + bootstrap scripts are baked in,
# so the role's cloud-init only writes config and starts k3s. Private image on
# ghcr.io/dev1l — registered in the account with a registry credential (see ../image).
data "durantic_image" "k3s" {
  name = "durantic-k3s-argocd:latest"
}

resource "durantic_mesh_network" "cluster" {
  name                 = "${local.cluster_name}-mesh"
  network_cidr         = local.mesh_cidr
  route_reflector_mode = false
}

# --- ArgoCD config ---
resource "durantic_variable" "argocd_repo_url" {
  name        = "K3S_STANDALONE_ARGOCD_REPO_URL"
  value       = var.argocd_repo_url
  description = "GitOps repo URL for the k3s-standalone-argocd example"
}

resource "durantic_variable" "argocd_target_revision" {
  name        = "K3S_STANDALONE_ARGOCD_TARGET_REVISION"
  value       = var.argocd_target_revision
  description = "Git branch ArgoCD tracks for the k3s-standalone-argocd example"
}

resource "durantic_variable" "argocd_app_path" {
  name        = "K3S_STANDALONE_ARGOCD_APP_PATH"
  value       = var.argocd_app_path
  description = "Path in the repo containing the app-of-apps Applications"
}

# --- Secrets ---
resource "durantic_secret" "k3s_cluster_token" {
  name        = "K3S_STANDALONE_ARGOCD_CLUSTER_TOKEN"
  value       = var.k3s_cluster_token
  description = "k3s server token for the k3s-standalone-argocd example"
}

resource "durantic_secret" "ghcr_token" {
  name        = "K3S_STANDALONE_ARGOCD_GHCR_TOKEN"
  value       = var.ghcr_token
  description = "ghcr.io PAT used by k3s (containerd) to pull the private app images"
}

# --- Roles ---
resource "durantic_machine_role" "ssh_keys" {
  name           = local.ssh_keys_role_name
  description    = "Imports configured GitHub SSH keys on the ${local.cluster_name} node"
  merge_priority = 20
  template_data  = local.ssh_keys_template
}

resource "durantic_machine_role" "k3s_argocd" {
  name           = local.k3s_role_name
  description    = "Single-node k3s + ArgoCD (standalone, no gateway) for ${local.cluster_name}"
  image_uuid     = data.durantic_image.k3s.uuid
  merge_priority = 100
  requires_mesh  = true
  template_data  = file("${path.module}/templates/k3s-argocd.cloud-init.yaml")
}

# --- Deployment ---
resource "durantic_machine_deployment" "node" {
  machine_uuid      = data.durantic_machine.node.uuid
  mesh_network_uuid = durantic_mesh_network.cluster.uuid

  role_names = [
    durantic_machine_role.ssh_keys.name,
    durantic_machine_role.k3s_argocd.name,
  ]

  depends_on = [
    durantic_secret.k3s_cluster_token,
    durantic_secret.ghcr_token,
    durantic_variable.argocd_repo_url,
    durantic_variable.argocd_target_revision,
    durantic_variable.argocd_app_path,
  ]

  # Bump to force a re-provision without a config change.
  force_provision = "v1"
}
