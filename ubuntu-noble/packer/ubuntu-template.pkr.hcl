# Packer configuration for Ubuntu 24.04 base template on Proxmox
# Complete Vault integration using existing secret structure

packer {
  required_version = ">= 1.9.0"

  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Local variables - all from Vault kv/proxmox
locals {
  # Proxmox credentials from Vault
  proxmox_api_url          = vault("kv/data/proxmox", "api_url")
  proxmox_api_token_id     = vault("kv/data/proxmox", "api_token_id")
  proxmox_api_token_secret = vault("kv/data/proxmox", "api_token_secret")

  # User configurations from Vault
  default_user                = vault("kv/data/proxmox", "default_user")
  default_user_ssh_key        = vault("kv/data/proxmox", "default_user_ssh_key")
  default_user_ssh_pass       = vault("kv/data/proxmox", "default_user_ssh_pass")        # Plaintext for SSH
  default_user_password_hash  = vault("kv/data/proxmox", "default_user_password_hash")  # SHA-512 for cloud-init
  ansible_user                = vault("kv/data/proxmox", "ansible_user")
  ansible_user_ssh_key        = vault("kv/data/proxmox", "ansible_user_ssh_key")
  ansible_user_ssh_pass       = vault("kv/data/proxmox", "ansible_user_ssh_pass")       # Plaintext for SSH
  ansible_user_password_hash  = vault("kv/data/proxmox", "ansible_user_password_hash")  # SHA-512 for cloud-init

  # Build metadata
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

# Source configuration for Proxmox
source "proxmox-iso" "ubuntu-noble" {
  # Proxmox connection
  proxmox_url              = local.proxmox_api_url
  username                 = local.proxmox_api_token_id
  token                    = local.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node    = var.proxmox_node
  vm_id   = var.vm_id  # null = Proxmox auto-allocates from available pool
  vm_name = var.vm_name

  # ISO download configuration - downloads to Proxmox storage
  boot_iso {
    type             = "scsi"
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.iso_storage_pool
    iso_download_pve = true
    unmount          = true
  }

  # VM Hardware
  cores   = var.cpu_cores
  memory  = var.memory
  sockets = 1

  # BIOS - UEFI with Secure Boot disabled
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.storage_pool
    pre_enrolled_keys = false  # Disable Secure Boot for Linux compatibility
  }

  # Disk configuration
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    type         = "scsi"
    format       = "raw"
    io_thread    = true
    discard      = true
    ssd          = true
  }

  # Network configuration
  network_adapters {
    model    = "virtio"
    bridge   = var.bridge
    vlan_tag = var.vlan_tag
    firewall = false
  }

  # Boot order - disk first, ISO second (will be ejected), then network
  boot = "order=scsi0;scsi1;net0"

  # Cloud-init configuration
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  # Boot configuration for Ubuntu autoinstall
  boot_wait = "5s"
  boot_command = [
    "<wait><esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]

  # HTTP server for autoinstall
  http_bind_address = "YOUR_IP_ADDRESS"  # CHANGE THIS: e.g., "192.168.1.100"
  http_port_min     = 8100
  http_port_max     = 8100
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data.pkrtpl.hcl", {
                      default_user          = local.default_user
                      default_user_ssh_key  = local.default_user_ssh_key
                      default_user_password = local.default_user_password_hash  # Use SHA-512 hash for cloud-init
                      ansible_user          = local.ansible_user
                      ansible_user_ssh_key  = local.ansible_user_ssh_key
                      ansible_user_password = local.ansible_user_password_hash  # Use SHA-512 hash for cloud-init
                    })
    "/meta-data"   = file("${path.root}/http/meta-data")
    "/vendor-data" = ""
  }

  # SSH configuration - using default user with SSH key
  ssh_username           = local.default_user
  ssh_password           = local.default_user_ssh_pass
  ssh_timeout            = "20m"
  ssh_handshake_attempts = 20

  # Template configuration
  template_name        = var.vm_name
  template_description = <<-EOT
    - Ubuntu 24.04 LTS Base Template
    - Built: ${local.timestamp}
    - OS: Ubuntu 24.04 LTS
    - Users: ${local.default_user}, ${local.ansible_user} (both with sudo NOPASSWD)
    - Custom partition schema with dedicated /var/log and tmpfs /tmp
    - Serial console: Configured for xterm.js (console=ttyS0,115200)
    - Built with: Packer + HashiCorp Vault
  EOT

  # Additional VM settings
  qemu_agent = true
  os         = "l26"

  # Serial port configuration for xterm.js console
  serials = ["socket"]

  # Tags
  tags = "template;ubuntu-24-04;base;packer"
}

# Build definition
build {
  name    = "ubuntu-base-template"
  sources = ["source.proxmox-iso.ubuntu-noble"]

  # Pre-build: Write SSH private key to temporary file
  provisioner "shell-local" {
    inline = [
      "echo '${local.default_user_ssh_key}' > /tmp/packer-ssh-key",
      "chmod 600 /tmp/packer-ssh-key"
    ]
  }

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Still waiting...'; sleep 2; done",
      "sudo cloud-init status --wait",
      "echo 'Cloud-init completed successfully'"
    ]
  }

  # Verify both users and sudo setup
  provisioner "shell" {
    inline = [
      "echo 'Verifying user setup...'",
      "id ${local.default_user}",
      "id ${local.ansible_user}",
      "sudo -l -U ${local.default_user}",
      "sudo -l -U ${local.ansible_user}",
      "groups ${local.default_user}",
      "groups ${local.ansible_user}"
    ]
  }

  # System updates and base packages
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo apt-get install -y apt-transport-https software-properties-common wget curl ca-certificates"
    ]
  }

  # Install system utilities
  provisioner "shell" {
    inline = [
      "echo 'Installing system tools...'",
      "sudo apt-get install -y htop btop tmux vim nano net-tools dnsutils iputils-ping",
      "sudo apt-get install -y jq unzip zip bzip2 gzip python3 python3-pip",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent"
    ]
  }

  # Install ATIX subscription-manager for Foreman/Katello integration
  provisioner "shell" {
    inline = [
      "echo 'Installing ATIX subscription-manager...'",
      "# Add ATIX repository for Ubuntu 24.04 LTS",
      "sudo mkdir -p /etc/apt/keyrings",
      "sudo curl --silent --show-error --output /etc/apt/keyrings/atix.asc https://oss.atix.de/atix_gpg.pub",
      "# Create DEB822 format sources file",
      "sudo tee /etc/apt/sources.list.d/atix.sources > /dev/null <<EOF",
      "Types: deb",
      "URIs: https://oss.atix.de/Ubuntu24LTS/",
      "Suites: stable",
      "Components: main",
      "Signed-By: /etc/apt/keyrings/atix.asc",
      "EOF",
      "# Update and install subscription-manager",
      "sudo apt-get update",
      "sudo apt-get install -y subscription-manager",
      "echo 'ATIX subscription-manager installed successfully'"
    ]
  }

  # Configure system settings
  provisioner "shell" {
    inline = [
      "echo 'Configuring system settings...'",
      "sudo timedatectl set-timezone YOUR_TIMEZONE"  # CHANGE THIS: e.g., "America/New_York", "Europe/London"
    ]
  }

  # SSH configuration: Enable both password and key authentication
  provisioner "shell" {
    inline = [
      "echo 'Configuring SSH for password and key authentication...'",
      "sudo sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config",
      "echo 'Both SSH key and password authentication enabled'"
    ]
  }

  # Configure GRUB for serial console (xterm.js support)
  provisioner "shell" {
    inline = [
      "echo 'Configuring GRUB for serial console...'",
      "sudo sed -i '/^GRUB_CMDLINE_LINUX=/d' /etc/default/grub",
      "sudo sh -c 'echo \"GRUB_CMDLINE_LINUX=\\\"quiet console=tty0 console=ttyS0,115200\\\"\" >> /etc/default/grub'",
      "sudo update-grub",
      "echo 'Serial console configured for xterm.js'"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo cloud-init clean --logs --seed",
      "sudo sync"
    ]
  }

  # Post-build: Clean up SSH key file
  provisioner "shell-local" {
    inline = [
      "rm -f /tmp/packer-ssh-key"
    ]
  }

  # Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      build_time   = local.timestamp
      vm_id        = coalesce(var.vm_id, "auto-allocated")
      vm_name      = var.vm_name
      proxmox_node = var.proxmox_node
      users        = "${local.default_user},${local.ansible_user}"
    }
  }
}
