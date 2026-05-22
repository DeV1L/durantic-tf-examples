variable "k8s_cluster_token" {
  description = "Shared RKE2 cluster join token. Generate one with: openssl rand -hex 32"
  type        = string
  sensitive   = true
  default     = "bbe7cebcaca98b9ace03906a4989b018c461ddc584f96f82e59e862d4ce72e55"
}

variable "ssh_github_users" {
  description = "GitHub usernames whose public SSH keys will be imported on every cluster machine."
  type        = list(string)
  default = [
    "EvgeniyS-Planhat",
    "ivand6c",
    "vilorij",
  ]
}
