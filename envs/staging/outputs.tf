output "servers" {
  description = "IP e ID dei server di staging."
  value = {
    for k, s in module.server : k => {
      id   = s.id
      name = s.name
      ipv4 = s.ipv4_address
      ipv6 = s.ipv6_address
      # Rete privata e volume dati (null se assenti).
      private_ipv4 = s.private_ipv4
      volume_id    = try(module.volume[k].id, null)
    }
  }
}

# Letto dall'inventario Ansible (ansible/inventory/): IP, utente e CIDR
# restano definiti solo nei tfvars, senza duplicarli lato Ansible.
output "ansible_inventory" {
  description = "Host e variabili per l'inventario Ansible."
  value = {
    environment = local.environment
    admin_user  = var.admin_user
    hosts = {
      for k, s in module.server : s.name => {
        group              = k
        ansible_host       = s.ipv4_address
        allowed_ssh_cidrs  = var.servers[k].allowed_ssh_cidrs
        allowed_http_cidrs = var.servers[k].allowed_http_cidrs
        private_ipv4       = s.private_ipv4
        network_ip_range   = module.network.ip_range
        data_volume_device = try(module.volume[k].linux_device, null)
      }
    }
  }
}
