# Variables for Debian Trixie base template build
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
  default     = "debian-trixie-base"
}

# ISO download configuration
variable "iso_url" {
  type        = string
  description = "URL to download Debian 13.2.0 (Trixie) ISO - Stable release"
  default     = "https://cdimage.debian.org/cdimage/release/13.2.0/amd64/iso-cd/debian-13.2.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "ISO checksum (format: type:hash)"
  default     = "sha512:891d7936a2e21df1d752e5d4c877bb7ca2759c902b0bfbf5527098464623bedaa17260e8bd4acf1331580ae56a6a87a08cc2f497102daa991d5e4e4018fee82b"
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
