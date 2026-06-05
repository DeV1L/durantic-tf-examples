terraform {
  required_providers {
    durantic = {
      source  = "registry.durantic.io/durantic/durantic"
      version = "~> 1.0"
    }
  }
}

provider "durantic" {
  # api_token read from DURANTIC_API_TOKEN
  # endpoint read from DURANTIC_ENDPOINT, for example https://api.demo.durantic.dev
}

locals {
  app_name = "demo"

  mesh_cidr   = "10.61.0.0/24"
  backend_vip = "10.61.0.100" # VIP "Render" — the backend

  mongodb_password_secret_name = "NODEJS_APP_MONGODB_PASSWORD"

  ssh_keys_role_name = "${local.app_name}-ssh-keys"
  mongodb_role_name  = "${local.app_name}-mongodb"
  backend_role_name  = "${local.app_name}-backend"
  frontend_role_name = "${local.app_name}-frontend"

  ssh_keys_template = <<-EOT
    #cloud-config
    #
    # Imports public SSH keys from GitHub.

    ssh_import_id:
    %{for user in var.ssh_github_users~}
      - gh:${user}
    %{endfor~}
  EOT

  # MongoDB tier: writes credentials + mesh bind address, then starts native mongod.
  mongodb_template = <<-EOT
    #cloud-config
    #
    # MongoDB role. Configures and starts native mongod, bound to the mesh interface.

    write_files:
      - path: /etc/durantic/mongodb.env
        owner: root:root
        permissions: '0600'
        content: |
          MONGO_ROOT_PASSWORD="{{ secrets.${local.mongodb_password_secret_name} }}"
          MESH_IP="{{ machine.mesh.ip }}"

    runcmd:
      - /usr/local/bin/mongodb-bootstrap.sh
  EOT

  # Backend tier: connects to MongoDB directly over the mesh. The mongo machine's mesh IP
  # isn't known at plan time, so we discover it from the peers context (the peer carrying
  # the mongodb role), the same way the rke2 example discovers server peers.
  backend_template = <<-EOT
    #cloud-config
    #
    # Backend role. Renders PDFs and stores them in MongoDB (reached over the mesh).

    {% set ns = namespace(mongo_ip='') %}
    {% for peer in peers %}
    {% if '${local.mongodb_role_name}' in peer.roles %}
    {% set ns.mongo_ip = peer.mesh.ip %}
    {% endif %}
    {% endfor %}

    write_files:
      - path: /etc/durantic/backend.env
        owner: root:root
        permissions: '0600'
        content: |
          MONGODB_URL="mongodb://root:{{ secrets.${local.mongodb_password_secret_name} }}@{{ ns.mongo_ip }}:27017/?authSource=admin"
          PORT="3000"

    runcmd:
      - /usr/local/bin/backend-bootstrap.sh
  EOT

  # Frontend tier: the only public-facing node. Proxies /api to the backend VIP.
  frontend_template = <<-EOT
    #cloud-config
    #
    # Frontend role. Serves the UI on :80 and proxies /api to the backend VIP.

    write_files:
      - path: /etc/durantic/frontend.env
        owner: root:root
        permissions: '0600'
        content: |
          BACKEND_URL="http://${local.backend_vip}:3000"
          PORT="80"

    runcmd:
      - /usr/local/bin/frontend-bootstrap.sh
  EOT
}

data "durantic_machine" "frontend" {
  hostname = var.frontend_hostname
}

data "durantic_machine" "backend" {
  hostname = var.backend_hostname
}

data "durantic_machine" "mongodb" {
  hostname = var.mongodb_hostname
}

data "durantic_image" "frontend" {
  docker_image_url = var.frontend_image
}

data "durantic_image" "backend" {
  docker_image_url = var.backend_image
}

data "durantic_image" "mongodb" {
  docker_image_url = var.mongodb_image
}

resource "durantic_mesh_network" "app" {
  name                 = "${local.app_name}-mesh"
  network_cidr         = local.mesh_cidr
  route_reflector_mode = false
}

resource "durantic_vip" "backend" {
  name    = "${local.app_name}-backend-vip"
  address = local.backend_vip
  enabled = true

  machine_uuids = [data.durantic_machine.backend.uuid]

  health_check_type                = "tcp"
  health_check_target              = ":3000"
  health_check_interval_seconds    = 5
  health_check_timeout_seconds     = 3
  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3
}

resource "durantic_secret" "mongodb_password" {
  name        = local.mongodb_password_secret_name
  value       = var.mongodb_password
  description = "MongoDB root password for the ${local.app_name} demo"
}

resource "durantic_machine_role" "ssh_keys" {
  name           = local.ssh_keys_role_name
  description    = "Imports configured GitHub SSH keys on every ${local.app_name} machine"
  merge_priority = 20
  template_data  = local.ssh_keys_template
}

resource "durantic_machine_role" "mongodb" {
  name           = local.mongodb_role_name
  description    = "MongoDB tier for ${local.app_name}"
  image_uuid     = data.durantic_image.mongodb.uuid
  merge_priority = 100
  requires_mesh  = true
  template_data  = local.mongodb_template
}

resource "durantic_machine_role" "backend" {
  name           = local.backend_role_name
  description    = "Backend (PDF generator) tier for ${local.app_name}"
  image_uuid     = data.durantic_image.backend.uuid
  merge_priority = 100
  requires_mesh  = true
  vip_uuid       = durantic_vip.backend.uuid
  template_data  = local.backend_template
}

resource "durantic_machine_role" "frontend" {
  name           = local.frontend_role_name
  description    = "Frontend (UI + API proxy) tier for ${local.app_name}"
  image_uuid     = data.durantic_image.frontend.uuid
  merge_priority = 100
  requires_mesh  = true
  template_data  = local.frontend_template
}

resource "durantic_machine_deployment" "mongodb" {
  machine_uuid      = data.durantic_machine.mongodb.uuid
  mesh_network_uuid = durantic_mesh_network.app.uuid

  role_names = [
    durantic_machine_role.ssh_keys.name,
    durantic_machine_role.mongodb.name,
  ]

  depends_on = [
    durantic_secret.mongodb_password,
  ]

  # Bumped to v2 to re-provision with the native mongod image (was docker-based)
  force_provision = "v2"
}

resource "durantic_machine_deployment" "backend" {
  machine_uuid      = data.durantic_machine.backend.uuid
  mesh_network_uuid = durantic_mesh_network.app.uuid

  role_names = [
    durantic_machine_role.ssh_keys.name,
    durantic_machine_role.backend.name,
  ]

  depends_on = [
    durantic_secret.mongodb_password,
  ]

  # Bumped to v2 to re-provision the backend with the VIP-free MongoDB config
  force_provision = "v2"
}

resource "durantic_machine_deployment" "frontend" {
  machine_uuid      = data.durantic_machine.frontend.uuid
  mesh_network_uuid = durantic_mesh_network.app.uuid

  role_names = [
    durantic_machine_role.ssh_keys.name,
    durantic_machine_role.frontend.name,
  ]

  force_provision = "v1"
}
