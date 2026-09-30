variable "name" {
  description = "Nome logico del server (es. nautica, ai). Il nome Hetzner diventa <environment>-<name>."
  type        = string
}

variable "environment" {
  description = "Ambiente (staging, prod). Usato per nome e label."
  type        = string
}

variable "server_type" {
  description = "Tipo di server Hetzner (es. cx23)."
  type        = string
}

variable "location" {
  description = "Location Hetzner (es. nbg1, fsn1, hel1)."
  type        = string
}

variable "image" {
  description = "Immagine del sistema operativo."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_key_ids" {
  description = "ID delle hcloud_ssh_key da installare su root al primo avvio (il login root viene poi disabilitato da cloud-init)."
  type        = list(string)
}

variable "admin_user" {
  description = "Utente non-root con sudo creato da cloud-init."
  type        = string
  default     = "deploy"
}

variable "admin_ssh_public_keys" {
  description = "Chiavi SSH pubbliche autorizzate per l'utente admin (una per persona del team)."
  type        = list(string)

  validation {
    condition     = length(var.admin_ssh_public_keys) > 0
    error_message = "Serve almeno una chiave SSH pubblica, altrimenti nessuno può accedere al server."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ammessi su SSH (22). Lista vuota = SSH chiuso."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_ssh_cidrs deve contenere solo CIDR validi (es. 1.2.3.4/32)."
  }
}

variable "allowed_http_cidrs" {
  description = "CIDR ammessi su 80/443. Lista vuota = HTTP/HTTPS chiusi."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_http_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_http_cidrs deve contenere solo CIDR validi."
  }
}

variable "allow_icmp" {
  description = "Ammette ping (ICMP) in ingresso."
  type        = bool
  default     = true
}

variable "backups" {
  description = "Backup automatici Hetzner (+20% del costo del server)."
  type        = bool
  default     = true
}

variable "protection" {
  description = "Attiva delete_protection e rebuild_protection (da usare in prod)."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Label aggiuntive, unite a quelle standard (env, project, managed-by)."
  type        = map(string)
  default     = {}
}
