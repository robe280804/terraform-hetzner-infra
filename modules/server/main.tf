locals {
  full_name = "${var.environment}-${var.name}"

  labels = merge(var.labels, {
    env        = var.environment
    project    = var.name
    managed-by = "terraform"
  })
}

# Deny-by-default: su Hetzner un firewall applicato blocca tutto l'ingresso
# non esplicitamente ammesso. L'uscita resta libera (nessuna regola "out").
resource "hcloud_firewall" "this" {
  name   = local.full_name
  labels = local.labels

  dynamic "rule" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      direction   = "in"
      protocol    = "tcp"
      port        = "22"
      source_ips  = var.allowed_ssh_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_http_cidrs) > 0 ? toset(["80", "443"]) : toset([])
    content {
      description = "HTTP/HTTPS ${rule.value}"
      direction   = "in"
      protocol    = "tcp"
      port        = rule.value
      source_ips  = var.allowed_http_cidrs
    }
  }

  dynamic "rule" {
    for_each = var.allow_icmp ? [1] : []
    content {
      description = "ICMP"
      direction   = "in"
      protocol    = "icmp"
      source_ips  = ["0.0.0.0/0", "::/0"]
    }
  }
}

resource "hcloud_server" "this" {
  name         = local.full_name
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = var.ssh_key_ids
  firewall_ids = [hcloud_firewall.this.id]
  backups      = var.backups
  labels       = local.labels

  delete_protection  = var.protection
  rebuild_protection = var.protection

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    admin_user            = var.admin_user
    admin_ssh_public_keys = var.admin_ssh_public_keys
    open_http             = length(var.allowed_http_cidrs) > 0
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  lifecycle {
    # Modificare questi campi ricreerebbe il server da zero (dati persi).
    # Il cloud-init gira solo al primo avvio: le modifiche successive vanno fatte con Ansible.
    ignore_changes = [user_data, ssh_keys, image]
  }
}
