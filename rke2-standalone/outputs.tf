output "cluster_name" {
  value = local.cluster_name
}

output "k8s_vip" {
  value = durantic_vip.cluster.address
}

output "init_master" {
  value = {
    hostname = local.master_hostnames[0]
    uuid     = durantic_machine_deployment.masters[local.master_hostnames[0]].machine_uuid
    mesh_ip  = durantic_machine_deployment.masters[local.master_hostnames[0]].wg_ip_address
  }
}

output "masters" {
  value = {
    for hostname, machine in durantic_machine_deployment.masters : hostname => {
      uuid       = machine.machine_uuid
      mesh_ip    = machine.wg_ip_address
      public_ips = data.durantic_machine.masters[hostname].public_ip_addresses
    }
  }
}

output "workers" {
  value = {
    for hostname, machine in durantic_machine_deployment.workers : hostname => {
      uuid    = machine.machine_uuid
      mesh_ip = machine.wg_ip_address
    }
  }
}

output "roles" {
  value = {
    cluster_init = {
      name = durantic_machine_role.cluster_init.name
      uuid = durantic_machine_role.cluster_init.uuid
    }
    server = {
      name = durantic_machine_role.server.name
      uuid = durantic_machine_role.server.uuid
    }
    agent = {
      name = durantic_machine_role.agent.name
      uuid = durantic_machine_role.agent.uuid
    }
    ssh_keys = {
      name = durantic_machine_role.ssh_keys.name
      uuid = durantic_machine_role.ssh_keys.uuid
    }
  }
}
