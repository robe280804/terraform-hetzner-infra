locals {
  environment = "staging"

  # Chiavi SSH pubbliche del team, versionate in ssh_keys/<persona>.pub.
  # Aggiungere/rimuovere una persona = aggiungere/rimuovere un file via PR.
  admin_ssh_public_keys = {
    for f in fileset("${path.module}/ssh_keys", "*.pub") :
    trimsuffix(f, ".pub") => trimspace(file("${path.module}/ssh_keys/${f}"))
  }
}

# Una hcloud_ssh_key per persona, condivisa da tutti i server dell'ambiente:
# Hetzner rifiuta la stessa chiave pubblica caricata due volte nello stesso Project.
resource "hcloud_ssh_key" "admin" {
  for_each = local.admin_ssh_public_keys

  name       = "${local.environment}-${each.key}"
  public_key = each.value

  labels = {
    env        = local.environment
    owner      = each.key
    managed-by = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  environment     = local.environment
  ip_range        = var.network.ip_range
  subnet_ip_range = var.network.subnet_ip_range
  network_zone    = var.network.network_zone
}

module "server" {
  source   = "../../modules/server"
  for_each = var.servers

  name        = each.key
  environment = local.environment
  server_type = each.value.server_type
  location    = each.value.location
  image       = each.value.image
  backups     = each.value.backups

  ssh_key_ids           = [for k in hcloud_ssh_key.admin : k.id]
  admin_user            = var.admin_user
  admin_ssh_public_keys = values(local.admin_ssh_public_keys)

  allowed_ssh_cidrs  = each.value.allowed_ssh_cidrs
  allowed_http_cidrs = each.value.allowed_http_cidrs

  network = {
    subnet_id = module.network.subnet_id
    ip        = each.value.private_ip
  }

  protection = false
}

# Un volume dati per ogni server con volume_size > 0.
module "volume" {
  source   = "../../modules/volume"
  for_each = { for k, s in var.servers : k => s if s.volume_size > 0 }

  name        = each.key
  environment = local.environment
  size        = each.value.volume_size
  location    = each.value.location
  server_id   = module.server[each.key].id

  protection = false
}
