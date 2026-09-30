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

variable "servers" {
  description = "Server dell'ambiente: una voce per server (es. nautica, ai)."
  type = map(object({
    server_type        = string
    location           = string
    allowed_ssh_cidrs  = list(string)
    allowed_http_cidrs = optional(list(string), [])
    image              = optional(string, "ubuntu-24.04")
    backups            = optional(bool, true)
  }))
}
