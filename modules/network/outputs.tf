output "network_id" {
  description = "ID della rete."
  value       = hcloud_network.this.id
}

output "subnet_id" {
  description = "ID della subnet dei server (da passare al modulo server)."
  value       = hcloud_network_subnet.this.id
}

output "ip_range" {
  description = "Range della rete."
  value       = hcloud_network.this.ip_range
}
