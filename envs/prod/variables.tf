variable "hcloud_token" {
  description = "API token del Project Hetzner prod (passare via TF_VAR_hcloud_token, mai in chiaro nel repo)"
  type        = string
  sensitive   = true
}
