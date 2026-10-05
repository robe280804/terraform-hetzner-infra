output "servers" {
  description = "IP e ID dei server di staging."
  value = {
    for k, s in module.server : k => {
      id   = s.id
      name = s.name
      ipv4 = s.ipv4_address
      ipv6 = s.ipv6_address
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
      }
    }
  }
}
