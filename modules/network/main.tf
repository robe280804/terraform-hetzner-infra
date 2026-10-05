locals {
  labels = merge(var.labels, {
    env        = var.environment
    managed-by = "terraform"
  })
}

# Rete privata dell'ambiente: il traffico tra server non passa da internet.
# Il firewall Hetzner filtra solo le interfacce pubbliche: sulla rete privata
# l'unica barriera è ufw sul server (deny-by-default anche lì).
resource "hcloud_network" "this" {
  name              = var.environment
  ip_range          = var.ip_range
  labels            = local.labels
  delete_protection = var.protection
}

resource "hcloud_network_subnet" "this" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_ip_range
}
