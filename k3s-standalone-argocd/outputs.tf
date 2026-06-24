output "cluster_name" {
  value = local.cluster_name
}

output "node" {
  description = "The single k3s node."
  value = {
    hostname   = data.durantic_machine.node.hostname
    uuid       = data.durantic_machine.node.uuid
    mesh_ip    = durantic_machine_deployment.node.wg_ip_address
    public_ips = data.durantic_machine.node.public_ip_addresses
  }
}

output "app_url" {
  description = "Three-tier app frontend (Traefik ingress on :80)."
  value       = try("http://${data.durantic_machine.node.public_ip_addresses[0]}/", "http://<node-public-ip>/")
}

output "argocd_url" {
  description = "ArgoCD UI (NodePort :30080, insecure HTTP)."
  value       = try("http://${data.durantic_machine.node.public_ip_addresses[0]}:30080", "http://<node-public-ip>:30080")
}

output "argocd_admin_password_hint" {
  description = "Read the auto-generated ArgoCD admin password (user: admin)."
  value       = "ssh root@<node-public-ip> \"k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d\""
}

output "provision_status" {
  description = "Terminal status of the provision triggered by this apply."
  value       = durantic_machine_deployment.node.provision_status
}

output "roles" {
  value = {
    ssh_keys   = durantic_machine_role.ssh_keys.name
    k3s_argocd = durantic_machine_role.k3s_argocd.name
  }
}
