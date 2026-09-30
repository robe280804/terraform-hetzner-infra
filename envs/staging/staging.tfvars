# Config condivisa di staging: versionata, ogni modifica passa da PR.
# Le chiavi SSH pubbliche del team stanno in ssh_keys/*.pub (una per persona).

admin_user = "deploy"

servers = {
  nautica = {
    # cx23: il tipo x86 più economico, sufficiente per i test.
    server_type = "cx23"
    location    = "nbg1"
    # Mio IP curl -4 ifconfig.me
    allowed_ssh_cidrs  = ["95.228.48.254/32"]
    allowed_http_cidrs = []
    # Backup Hetzner (+20% del costo): spenti in staging.
    backups = false
  }
}
