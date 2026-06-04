output "app_name" {
  value = local.app_name
}

output "app_url" {
  description = "Open this in a browser. First discovered public IP of the frontend machine."
  value = try(
    "http://${data.durantic_machine.frontend.public_ip_addresses[0]}",
    "frontend public IP not discovered yet",
  )
}

output "backend_vip" {
  value = durantic_vip.backend.address
}

output "mongodb_vip" {
  value = durantic_vip.mongodb.address
}

output "frontend" {
  value = {
    hostname   = var.frontend_hostname
    uuid       = durantic_machine_deployment.frontend.machine_uuid
    mesh_ip    = durantic_machine_deployment.frontend.wg_ip_address
    public_ips = data.durantic_machine.frontend.public_ip_addresses
  }
}

output "backend" {
  value = {
    hostname   = var.backend_hostname
    uuid       = durantic_machine_deployment.backend.machine_uuid
    mesh_ip    = durantic_machine_deployment.backend.wg_ip_address
    public_ips = data.durantic_machine.backend.public_ip_addresses
  }
}

output "mongodb" {
  value = {
    hostname   = var.mongodb_hostname
    uuid       = durantic_machine_deployment.mongodb.machine_uuid
    mesh_ip    = durantic_machine_deployment.mongodb.wg_ip_address
    public_ips = data.durantic_machine.mongodb.public_ip_addresses
  }
}

output "roles" {
  value = {
    ssh_keys = {
      name = durantic_machine_role.ssh_keys.name
      uuid = durantic_machine_role.ssh_keys.uuid
    }
    mongodb = {
      name = durantic_machine_role.mongodb.name
      uuid = durantic_machine_role.mongodb.uuid
    }
    backend = {
      name = durantic_machine_role.backend.name
      uuid = durantic_machine_role.backend.uuid
    }
    frontend = {
      name = durantic_machine_role.frontend.name
      uuid = durantic_machine_role.frontend.uuid
    }
  }
}
