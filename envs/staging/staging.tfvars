# Config condivisa di staging: versionata, ogni modifica passa da PR.
# Le chiavi SSH pubbliche del team stanno in ssh_keys/*.pub (una per persona).

admin_user = "deploy"

# Rete privata: 10.10.0.0/16 staging, 10.20.0.0/16 prod (mai sovrapposte).
network = {
  ip_range        = "10.10.0.0/16"
  subnet_ip_range = "10.10.1.0/24"
}

servers = {
  nautica = {
    # cx23: il tipo x86 più economico, sufficiente per i test.
    server_type = "cx23"
    location    = "nbg1"
    # IP pubblici ammessi su SSH (il proprio: curl -4 ifconfig.me).
    # Cambiato l'IP? Aggiornare qui e `terraform apply`: tocca solo il firewall.
    allowed_ssh_cidrs = [
      "95.228.48.254/32", # ufficio
      "79.30.142.77/32",  # casa Roberto (dinamico, può cambiare)
    ]
    allowed_http_cidrs = []
    # Backup Hetzner (+20% del costo): spenti in staging.
    backups = false
    # IP fisso sulla rete privata: indirizzo stabile per gli altri server.
    private_ip = "10.10.1.10"
    # Volume dati separato (GB, minimo 10): sopravvive alla ricreazione del server.
    volume_size = 10
  }
}
