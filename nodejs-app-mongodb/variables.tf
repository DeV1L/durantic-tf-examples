variable "frontend_hostname" {
  description = "Hostname of the existing Durantic machine to run the frontend (Worker) tier."
  type        = string
  default     = "worker"
}

variable "backend_hostname" {
  description = "Hostname of the existing Durantic machine to run the backend (Render) tier."
  type        = string
  default     = "render"
}

variable "mongodb_hostname" {
  description = "Hostname of the existing Durantic machine to run the MongoDB tier."
  type        = string
  default     = "mongo"
}

variable "mongodb_password" {
  description = "MongoDB root password. Override for anything real: export TF_VAR_mongodb_password=\"$(openssl rand -hex 24)\""
  type        = string
  sensitive   = true
  default     = "demo-change-me-please"
}

variable "ssh_github_users" {
  description = "GitHub usernames whose public SSH keys will be imported on every machine."
  type        = list(string)
  default = [
    "EvgeniyS-Planhat",
    "ivand6c",
    "vilorij",
  ]
}

variable "frontend_image" {
  description = "Docker image URL for the frontend boot image."
  type        = string
  default     = "ghcr.io/dev1l/dur-example-nodejs-app-mongodb:frontend"
}

variable "backend_image" {
  description = "Docker image URL for the backend boot image."
  type        = string
  default     = "ghcr.io/dev1l/dur-example-nodejs-app-mongodb:backend"
}

variable "mongodb_image" {
  description = "Docker image URL for the MongoDB boot image."
  type        = string
  default     = "ghcr.io/dev1l/dur-example-nodejs-app-mongodb:mongodb"
}
