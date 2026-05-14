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
  # endpoint read from DURANTIC_ENDPOINT, for example https://api.dev01.durantic.dev
}

locals {
  cluster_name = "rke2-standalone-dev01"

  master_hostnames = [
    "disposable-scaleway-01",
    "disposable-scaleway-02",
  ]

  worker_hostnames = [
    "disposable-scaleway-03",
    "disposable-scaleway-04",
    "disposable-scaleway-05",
  ]

  mesh_cidr = "10.60.0.0/24"
  k8s_vip   = "10.60.0.100"

  k8s_vip_variable_name         = "RKE2_STANDALONE_DEV01_K8S_VIP"
  k8s_cluster_token_secret_name = "RKE2_STANDALONE_DEV01_K8S_CLUSTER_TOKEN"

  cluster_init_role_name = "rke2-standalone-dev01-cluster-init"
  server_role_name       = "rke2-standalone-dev01-rke2-server"
  agent_role_name        = "rke2-standalone-dev01-rke2-agent"
  ssh_keys_role_name     = "rke2-standalone-dev01-ssh-keys"

  cluster_init_template = <<-EOT
    #cloud-config
    #
    # Marks this machine as the RKE2 cluster initializer.
    # Assign this role to exactly one master.

    write_files:
      - path: /etc/durantic/cluster-init
        owner: root:root
        permissions: '0644'
        content: "true"
  EOT

  server_template = <<-EOT
    #cloud-config
    #
    # RKE2 standalone server role without ArgoCD.
    # Masters are reachable directly through discovered public IPs.
    # The mesh-internal VIP provides HA for worker joins and internal API access.

    {% set rke2_peers = [] %}
    {% for peer in peers %}
    {% if '${local.server_role_name}' in peer.roles %}
    {% set _ = rke2_peers.append(peer) %}
    {% endif %}
    {% endfor %}
    {% set all_rke2 = [machine] + rke2_peers %}
    {% set all_rke2_sorted = all_rke2 | sort(attribute='mesh.ip') %}

    write_files:
      - path: /etc/hosts
        owner: root:root
        permissions: '0644'
        append: true
        content: |
          127.0.0.1 localhost
          ::1 localhost ip6-localhost ip6-loopback

      - path: /etc/rancher/rke2/config.yaml
        owner: root:root
        permissions: '0600'
        content: |
          node-ip: "{{ machine.mesh.ip }}"
          advertise-address: "{{ machine.mesh.ip }}"
          disable-cloud-controller: true
          flannel-iface: "durantic-wg"
          tls-san:
    {% for node in all_rke2_sorted %}
            - "{{ node.mesh.ip }}"
            - "{{ node.hostname }}"
    {% endfor %}
    {% for ip in machine.discovered_ip_addresses | default([]) %}
            - "{{ ip }}"
    {% endfor %}
    {% if role.vip is defined %}
            - "{{ role.vip }}"
    {% endif %}
          token: "{{ secrets.${local.k8s_cluster_token_secret_name} }}"

      - path: /etc/durantic/rke2-peers.env
        owner: root:root
        permissions: '0600'
        content: |
    {% for node in all_rke2_sorted %}
          {{ node.mesh.ip }}
    {% endfor %}

    runcmd:
      - /usr/local/bin/rke2-bootstrap.sh
  EOT

  agent_template = <<-EOT
    #cloud-config
    #
    # RKE2 agent worker role. Workers join through the mesh VIP on :9345.

    write_files:
      - path: /etc/hosts
        owner: root:root
        permissions: '0644'
        append: true
        content: |
          127.0.0.1 localhost
          ::1 localhost ip6-localhost ip6-loopback

      - path: /etc/rancher/rke2/config.yaml
        owner: root:root
        permissions: '0600'
        content: |
          node-ip: "{{ machine.mesh.ip }}"
          flannel-iface: "durantic-wg"

      - path: /etc/durantic/rke2-agent.env
        owner: root:root
        permissions: '0600'
        content: |
          SERVER_URL="{{ vars.${local.k8s_vip_variable_name} }}"
          TOKEN="{{ secrets.${local.k8s_cluster_token_secret_name} }}"

    runcmd:
      - /usr/local/bin/rke2-agent-bootstrap.sh
  EOT

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

data "durantic_machine" "masters" {
  for_each = toset(local.master_hostnames)

  hostname = each.key
}

data "durantic_machine" "workers" {
  for_each = toset(local.worker_hostnames)

  hostname = each.key
}

data "durantic_image" "rke2_server" {
  docker_image_url = "ghcr.io/durantic/linux-ubuntu-25.10:rke2-server-1.35"
}

data "durantic_image" "rke2_agent" {
  docker_image_url = "ghcr.io/durantic/linux-ubuntu-25.10:rke2-agent-1.35"
}

resource "durantic_mesh_network" "cluster" {
  name                 = "${local.cluster_name}-mesh"
  network_cidr         = local.mesh_cidr
  route_reflector_mode = false
}

resource "durantic_vip" "cluster" {
  name    = "${local.cluster_name}-vip"
  address = local.k8s_vip
  enabled = true

  machine_uuids = [
    for hostname in local.master_hostnames : data.durantic_machine.masters[hostname].uuid
  ]

  health_check_type                = "tcp"
  health_check_target              = ":6443"
  health_check_interval_seconds    = 5
  health_check_timeout_seconds     = 3
  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3
}

resource "durantic_variable" "k8s_vip" {
  name        = local.k8s_vip_variable_name
  value       = durantic_vip.cluster.address
  description = "RKE2 standalone VIP used by workers as the :9345 join endpoint"
}

resource "durantic_secret" "k8s_cluster_token" {
  name        = local.k8s_cluster_token_secret_name
  value       = var.k8s_cluster_token
  description = "RKE2 standalone cluster join token"
}

resource "durantic_machine_role" "cluster_init" {
  name           = local.cluster_init_role_name
  description    = "Designates exactly one RKE2 master as the cluster initializer"
  merge_priority = 10
  template_data  = local.cluster_init_template
}

resource "durantic_machine_role" "server" {
  name           = local.server_role_name
  description    = "RKE2 standalone server role for ${local.cluster_name}"
  image_uuid     = data.durantic_image.rke2_server.uuid
  merge_priority = 100
  requires_mesh  = true
  vip_uuid       = durantic_vip.cluster.uuid
  template_data  = local.server_template
}

resource "durantic_machine_role" "agent" {
  name           = local.agent_role_name
  description    = "RKE2 standalone worker role for ${local.cluster_name}"
  image_uuid     = data.durantic_image.rke2_agent.uuid
  merge_priority = 100
  requires_mesh  = true
  template_data  = local.agent_template
}

resource "durantic_machine_role" "ssh_keys" {
  name           = local.ssh_keys_role_name
  description    = "Imports configured GitHub SSH keys on every ${local.cluster_name} machine"
  merge_priority = 20
  template_data  = local.ssh_keys_template
}

resource "durantic_machine_config" "masters" {
  for_each = data.durantic_machine.masters

  machine_uuid      = each.value.uuid
  mesh_network_uuid = durantic_mesh_network.cluster.uuid

  role_names = concat(
    [durantic_machine_role.ssh_keys.name],
    each.key == local.master_hostnames[0] ? [durantic_machine_role.cluster_init.name] : [],
    [durantic_machine_role.server.name],
  )
}

resource "durantic_machine_config" "workers" {
  for_each = data.durantic_machine.workers

  machine_uuid      = each.value.uuid
  mesh_network_uuid = durantic_mesh_network.cluster.uuid

  role_names = [
    durantic_machine_role.ssh_keys.name,
    durantic_machine_role.agent.name,
  ]
}
