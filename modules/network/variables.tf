variable "environment" {
  description = "Ambiente (staging, prod). Usato come nome della rete e nelle label."
  type        = string
}

variable "ip_range" {
  description = "Range della rete privata (es. 10.10.0.0/16). Diverso per ogni ambiente."
  type        = string

  validation {
    condition     = can(cidrhost(var.ip_range, 0))
    error_message = "ip_range deve essere un CIDR valido (es. 10.10.0.0/16)."
  }
}

variable "subnet_ip_range" {
  description = "Range della subnet dei server, contenuto in ip_range (es. 10.10.1.0/24)."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_ip_range, 0))
    error_message = "subnet_ip_range deve essere un CIDR valido (es. 10.10.1.0/24)."
  }
}

variable "network_zone" {
  description = "Network zone Hetzner: deve contenere le location dei server (eu-central = nbg1, fsn1, hel1)."
  type        = string
  default     = "eu-central"
}

variable "protection" {
  description = "Attiva la delete_protection della rete (da usare in prod)."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Label aggiuntive, unite a quelle standard (env, managed-by)."
  type        = map(string)
  default     = {}
}
