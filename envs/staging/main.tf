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

  protection = false
}
