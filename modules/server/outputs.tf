output "id" {
  description = "ID del server."
  value       = hcloud_server.this.id
}

output "name" {
  description = "Nome del server."
  value       = hcloud_server.this.name
}

output "ipv4_address" {
  description = "IPv4 pubblico."
  value       = hcloud_server.this.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 pubblico."
  value       = hcloud_server.this.ipv6_address
}

output "firewall_id" {
  description = "ID del firewall associato."
  value       = hcloud_firewall.this.id
}
