variable "node_hostname" {
  description = "Hostname of the existing Durantic machine to turn into a single-node k3s + ArgoCD cluster."
  type        = string
  default     = "k3s-argocd-demo"
}

variable "ssh_github_users" {
  description = "GitHub usernames whose public SSH keys are imported on the node."
  type        = list(string)
  default = [
    "DeV1L",
  ]
}

variable "argocd_repo_url" {
  description = "GitOps repo ArgoCD deploys from."
  type        = string
  default     = "https://github.com/DeV1L/argocd-example-apps"
}

variable "argocd_target_revision" {
  description = "Git branch ArgoCD tracks."
  type        = string
  default     = "irrisketch-demo"
}

variable "argocd_app_path" {
  description = "Path in the repo containing the app-of-apps Applications."
  type        = string
  default     = "nodejs-app-mongodb/apps"
}

variable "k3s_cluster_token" {
  description = "k3s server token. Override in real use: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = "8f3b1d9c2a47e60b5f8c1a93d4e72b06a9c5f1e84d7b3026c9af15e8d2b740c3"
}

variable "ghcr_token" {
  description = <<-EOT
    ghcr.io PAT (needs read:packages) used by k3s/containerd to pull the private app
    images ghcr.io/dev1l/argocd-example-nodejs-app-mongodb:{frontend,backend}.
    Set via: export TF_VAR_ghcr_token=ghp_xxx (never commit it).
  EOT
  type      = string
  sensitive = true
}
