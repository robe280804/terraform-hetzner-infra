locals {
  full_name = "${var.environment}-${var.name}-data"

  labels = merge(var.labels, {
    env        = var.environment
    project    = var.name
    managed-by = "terraform"
  })
}

# Disco dati separato dal server: sopravvive alla sua ricreazione.
# Hetzner crea il filesystem una sola volta, alla creazione del volume.
resource "hcloud_volume" "this" {
  name              = local.full_name
  size              = var.size
  location          = var.location
  format            = var.format
  labels            = local.labels
  delete_protection = var.protection
}

# Attachment separato dal volume: ricreare il server ricrea solo questo,
# il volume (e i dati) restano.
resource "hcloud_volume_attachment" "this" {
  volume_id = hcloud_volume.this.id
  server_id = var.server_id
  # Il mount lo fa Ansible (ruolo data_volume), per UUID e con nofail.
  automount = false
}
