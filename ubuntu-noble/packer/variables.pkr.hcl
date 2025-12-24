# Variables for Ubuntu 24.04 base template build
# Override with -var flags or .pkrvars.hcl file

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
  default     = "pve-node01"
}

variable "vm_id" {
  type        = number
  description = "VM template ID (omit for Proxmox auto-allocation)"
  default     = null
}

variable "vm_name" {
  type        = string
  description = "VM template name"
  default     = "ubuntu-noble-base"
}

# ISO download configuration
variable "iso_url" {
  type        = string
  description = "URL to download Ubuntu 24.04.3 LTS live-server ISO"
  default     = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type        = string
  description = "ISO checksum (format: type:hash)"
  default     = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
}

variable "iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool for ISO files"
  default     = "local"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for VM disks"
  default     = "local-lvm"
}

variable "cpu_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "memory" {
  type        = number
  description = "Memory in MB"
  default     = 2048
}

variable "disk_size" {
  type        = string
  description = "Disk size (minimum 35G for custom partition schema)"
  default     = "35G"
}

variable "vlan_tag" {
  type        = number
  description = "VLAN tag for network"
  default     = 0
}

variable "bridge" {
  type        = string
  description = "Node Bridge"
  default     = "vmbr0"
}
