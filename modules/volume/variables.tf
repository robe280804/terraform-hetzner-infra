variable "name" {
  description = "Nome logico del server a cui appartiene (es. nautica). Il volume diventa <environment>-<name>-data."
  type        = string
}

variable "environment" {
  description = "Ambiente (staging, prod). Usato per nome e label."
  type        = string
}

variable "size" {
  description = "Dimensione in GB (minimo 10). Si può solo aumentare, mai ridurre."
  type        = number

  validation {
    condition     = var.size >= 10 && var.size <= 10240
    error_message = "size deve stare tra 10 e 10240 GB."
  }
}

variable "location" {
  description = "Location del volume: deve essere la stessa del server."
  type        = string
}

variable "server_id" {
  description = "ID del server a cui collegare il volume."
  type        = string
}

variable "format" {
  description = "Filesystem creato da Hetzner alla creazione del volume."
  type        = string
  default     = "ext4"

  validation {
    condition     = contains(["ext4", "xfs"], var.format)
    error_message = "format deve essere ext4 o xfs."
  }
}

variable "protection" {
  description = "Attiva la delete_protection del volume (da usare in prod)."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Label aggiuntive, unite a quelle standard (env, project, managed-by)."
  type        = map(string)
  default     = {}
}
