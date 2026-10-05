output "id" {
  description = "ID del volume."
  value       = hcloud_volume.this.id
}

output "linux_device" {
  description = "Device del volume sul server (es. /dev/disk/by-id/scsi-0HC_Volume_<id>)."
  value       = hcloud_volume.this.linux_device
}

output "size" {
  description = "Dimensione in GB."
  value       = hcloud_volume.this.size
}
