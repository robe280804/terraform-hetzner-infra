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
