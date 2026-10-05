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

variable "network" {
  description = "Rete privata a cui collegare il server: subnet_id dal modulo network, ip opzionale (null = assegnato da Hetzner). null = nessuna rete privata."
  type = object({
    subnet_id = string
    ip        = optional(string)
  })
  default = null
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

# ---------------------------------------------------------------------------
# Hardening (cloud-init)
# ---------------------------------------------------------------------------

variable "timezone" {
  description = "Timezone del server. UTC: log correlabili tra server, nessuna ora legale."
  type        = string
  default     = "UTC"
}

variable "fail2ban_bantime" {
  description = "Durata del ban fail2ban dopo troppi tentativi falliti."
  type        = string
  default     = "1h"
}

variable "fail2ban_findtime" {
  description = "Finestra entro cui fail2ban conta i tentativi falliti."
  type        = string
  default     = "10m"
}

variable "fail2ban_maxretry" {
  description = "Tentativi falliti tollerati entro fail2ban_findtime."
  type        = number
  default     = 5

  validation {
    condition     = var.fail2ban_maxretry >= 1 && var.fail2ban_maxretry <= 20
    error_message = "fail2ban_maxretry deve stare tra 1 e 20."
  }
}

variable "journald_max_use" {
  description = "Spazio massimo su disco per il journal di systemd."
  type        = string
  default     = "500M"
}

variable "login_banner" {
  description = "Banner legale pre-autenticazione (/etc/issue, /etc/issue.net, Banner di sshd). Stringa vuota = nessun banner. Niente versioni, hostname o marchi: aiutano solo la ricognizione."
  type        = string
  default     = <<-EOT
    ***************************************************************************
                              ACCESSO RISERVATO

     Sistema di proprieta privata. L accesso e consentito esclusivamente al
     personale autorizzato. Ogni attivita su questo sistema e registrata e
     monitorata. L accesso non autorizzato e vietato e sara perseguito nelle
     sedi competenti. Se non sei un utente autorizzato, disconnettiti ora.
    ***************************************************************************
  EOT
}
