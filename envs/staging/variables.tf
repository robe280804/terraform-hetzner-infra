variable "hcloud_token" {
  description = "API token del Project Hetzner staging (passare via TF_VAR_hcloud_token, mai in chiaro nel repo)"
  type        = string
  sensitive   = true
}

variable "admin_user" {
  description = "Utente non-root con sudo creato sui server."
  type        = string
  default     = "deploy"
}

variable "network" {
  description = "Rete privata dell'ambiente."
  type = object({
    ip_range        = string
    subnet_ip_range = string
    network_zone    = optional(string, "eu-central")
  })
}

variable "servers" {
  description = "Server dell'ambiente: una voce per server (es. nautica, ai)."
  type = map(object({
    server_type        = string
    location           = string
    allowed_ssh_cidrs  = list(string)
    allowed_http_cidrs = optional(list(string), [])
    image              = optional(string, "ubuntu-24.04")
    backups            = optional(bool, true)
    private_ip         = optional(string)    # null = assegnato da Hetzner
    volume_size        = optional(number, 0) # GB, 0 = nessun volume dati
  }))
}
