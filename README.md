# Packer VM Templates for Proxmox

Production-ready Packer templates for building automated VM templates on Proxmox with HashiCorp Vault integration.

## Available Templates

### Debian 13 (Trixie)
- **Location**: `debian-trixie/`
- **Installer**: Preseed (traditional Debian automated installation)
- **Base System**: Debian 13.2.0 (Trixie Stable)
- **Use Case**: Stability-first, predictable releases, pure Debian ecosystem

### Ubuntu 24.04 LTS (Noble Numbat)
- **Location**: `ubuntu-noble/`
- **Installer**: Autoinstall (cloud-init based automation)
- **Base System**: Ubuntu 24.04.3 LTS
- **Use Case**: Hardware support, PPAs, commercial backing, cloud-native workflows

## Features

All templates include:

- ✓ **Vault Integration**: All credentials managed by HashiCorp Vault (no plaintext secrets)
- ✓ **Dual Users**: Admin user + automation user (both with SSH keys and sudo NOPASSWD)
- ✓ **Custom LVM Partitioning**: Separate partitions for `/var/log`, `/tmp`, `/var`, etc.
- ✓ **QEMU Guest Agent**: Better VM management and monitoring from Proxmox
- ✓ **Serial Console**: xterm.js support for web-based console access
- ✓ **Cloud-Init Ready**: Easy VM customization after cloning
- ✓ **UEFI Boot**: Modern EFI configuration with Secure Boot disabled
- ✓ **Network**: Traditional interface naming (eth0, eth1) for portability

## Prerequisites

### Required Infrastructure
- **Proxmox VE** 7.x or 8.x
  - At least one node with sufficient resources
  - Storage pools for VMs and ISOs
  - Network bridge configured
- **HashiCorp Vault**
  - Running and unsealed
  - KV v2 secrets engine enabled
  - Valid authentication token

### Required Software
- **Packer** ≥ 1.9.0 - [Download](https://www.packer.io/downloads)
- **Vault CLI** - [Download](https://www.vaultproject.io/downloads)

### Network Requirements
- IP address for Packer's HTTP server (must be reachable from Proxmox VMs)
- Internet connectivity for ISO downloads and packages
- Port 8100 (or your chosen HTTP port) not blocked by firewall

## Quick Start

### 1. Configure Vault

Store all credentials in Vault:

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="your-vault-token"

# Create the secret
vault kv put kv/proxmox \
  api_url="https://proxmox.example.com:8006/api2/json" \
  api_token_id="packer@pve!packer-token" \
  api_token_secret="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  default_user="admin" \
  default_user_ssh_key="ssh-rsa AAAAB3... admin@host" \
  default_user_ssh_pass="SecurePassword123!" \
  default_user_password_hash='$6$rounds=656000$...' \
  ansible_user="automation" \
  ansible_user_ssh_key="ssh-rsa AAAAB3... automation@host" \
  ansible_user_ssh_pass="AutomationPass456!" \
  ansible_user_password_hash='$6$rounds=656000$...'
```

**Generate password hashes**:
```bash
# Install mkpasswd
sudo apt-get install whois

# Generate SHA-512 hash
mkpasswd -m sha-512 'YourPassword'
```

### 2. Build a Template

Choose your distribution:

**Debian**:
```bash
cd debian-trixie/packer
packer init .
packer build .
```

**Ubuntu**:
```bash
cd ubuntu-noble/packer
packer init .
packer build .
```

### 3. Clone and Use

```bash
# Clone the template
qm clone TEMPLATE_ID 100 --name my-vm --full

# Configure with cloud-init
qm set 100 --ciuser myuser --sshkeys ~/.ssh/id_rsa.pub
qm set 100 --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1

# Start the VM
qm start 100
```

## Project Structure

```
templates/
├── README.md                    # This file
├── debian-trixie/
│   ├── README.md                # Debian-specific documentation
│   ├── QUICKSTART.md            # Quick build instructions
│   ├── CONTEXT.md               # Development context (not for production)
│   └── packer/
│       ├── debian-template.pkr.hcl    # Main Packer config
│       ├── variables.pkr.hcl          # Variable definitions
│       └── http/
│           └── preseed.cfg.pkrtpl     # Preseed automation template
└── ubuntu-noble/
    ├── README.md                # Ubuntu-specific documentation
    ├── QUICKSTART.md            # Quick build instructions
    ├── CONTEXT.md               # Development context (not for production)
    └── packer/
        ├── ubuntu-template.pkr.hcl    # Main Packer config
        ├── variables.pkr.hcl          # Variable definitions
        └── http/
            ├── user-data.pkrtpl.hcl   # Cloud-init autoinstall
            ├── meta-data              # Cloud-init metadata (empty)
            └── vendor-data            # Cloud-init vendor data (empty)
```

## Customization

### Override Variables

```bash
# Use different Proxmox node
packer build -var="proxmox_node=pve-node02" .

# Set custom VM ID and name
packer build -var="vm_id=9100" -var="vm_name=custom-template" .

# Adjust resources
packer build -var="cpu_cores=4" -var="memory=8192" -var="disk_size=100G" .

# Set network configuration
packer build -var="bridge=vmbr1" -var="vlan_tag=10" .
```

### Create Variable Files

Create `custom.pkrvars.hcl`:

```hcl
proxmox_node = "pve-node02"
vm_id        = 9100
vm_name      = "ubuntu-docker"
cpu_cores    = 4
memory       = 8192
disk_size    = "100G"
bridge       = "vmbr0"
vlan_tag     = 0
```

Build with:
```bash
packer build -var-file="custom.pkrvars.hcl" .
```

## Vault Secret Schema

| Key | Purpose | Format |
|-----|---------|--------|
| `api_url` | Proxmox API endpoint | `https://HOST:8006/api2/json` |
| `api_token_id` | API token identifier | `user@realm!token-name` |
| `api_token_secret` | API token secret | UUID format |
| `default_user` | Primary admin user | Username string |
| `default_user_ssh_key` | Admin SSH public key | Full SSH public key |
| `default_user_ssh_pass` | Admin SSH password | Plaintext (for Packer connection) |
| `default_user_password_hash` | Admin password hash | SHA-512 (for OS creation) |
| `ansible_user` | Automation user | Username string |
| `ansible_user_ssh_key` | Automation SSH public key | Full SSH public key |
| `ansible_user_ssh_pass` | Automation SSH password | Plaintext (for automation) |
| `ansible_user_password_hash` | Automation password hash | SHA-512 (for OS creation) |

## Troubleshooting

### Vault Connection Issues

```bash
# Check Vault server status
vault status

# Verify token validity
vault token lookup

# Test secret retrieval
vault kv get kv/proxmox
```

### Packer HTTP Server Unreachable

```bash
# Verify IP is accessible from Proxmox
ping YOUR_HTTP_IP  # From Proxmox node

# Check firewall
sudo ufw allow 8100/tcp  # If using UFW

# Test HTTP server
curl http://YOUR_HTTP_IP:8100/
```

### Build Hangs During Installation

1. Check Proxmox console to see what the VM is doing
2. Verify `boot_command` in the template file
3. Ensure ISO downloaded correctly to Proxmox
4. Check Packer logs for error messages

### SSH Timeout After Installation

1. Verify user was created (check preseed/autoinstall late_command)
2. Confirm SSH password in Vault matches template expectations
3. Check if VM received an IP: `qm guest cmd VMID network-get-interfaces`
4. Review cloud-init logs on the VM: `/var/log/cloud-init.log`

## Security Best Practices

1. **Never commit Vault tokens** to version control
2. **Use minimal Vault permissions**:
   ```hcl
   path "kv/data/proxmox" {
     capabilities = ["read"]
   }
   ```
3. **Rotate API tokens regularly** in Proxmox
4. **Prefer SSH keys** over passwords where possible
5. **Disable templates** after creation to prevent accidental boot
6. **Review logs** regularly for security events

## Comparison: Debian vs Ubuntu

| Aspect | Debian | Ubuntu |
|--------|--------|--------|
| Installer | Preseed | Autoinstall (cloud-init) |
| Config Format | Preseed text | YAML |
| Boot Command | Complex (full kernel cmdline) | Simple (2 parameters) |
| Partitioning | Recipe-based | Declarative YAML |
| Cloud-init | Installed separately | Native support |
| Packages | Debian repos only | Debian repos + PPAs |
| Release Cycle | Stable/Testing/Unstable | 6mo regular / 2yr LTS |
| Philosophy | Universal OS, stability-first | Enterprise/cloud-focused |
| Best For | Servers, stability, pure FOSS | Workstations, newer hardware |

## Advanced Topics

### CI/CD Integration

Automate template builds with GitHub Actions or GitLab CI:

```yaml
# .github/workflows/build-templates.yml
name: Build Packer Templates

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Packer
        uses: hashicorp/setup-packer@main
      - name: Build Debian Template
        env:
          VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
          VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
        run: |
          cd debian-trixie/packer
          packer init .
          packer build .
```

### Terraform Integration

Deploy VMs from templates:

```hcl
resource "proxmox_vm_qemu" "web_server" {
  name        = "web-${count.index + 1}"
  count       = 3
  target_node = "pve-node01"
  clone       = "debian-trixie-base"
  full_clone  = true

  # Cloud-init customization
  ciuser  = "admin"
  sshkeys = file("~/.ssh/id_rsa.pub")
  ipconfig0 = "ip=192.168.1.${count.index + 10}/24,gw=192.168.1.1"
}
```

## Contributing

This is a personal project template. Feel free to fork and adapt for your needs!

## License

MIT License - See individual template directories for details.

## Support

For detailed guides, see the blog posts:
- [Building Debian 13 Templates with Packer and HashiCorp Vault](https://blog.jlab.systems/posts/build-debian-trixie-template-with-packer/)
- [Building Ubuntu 24.04 LTS Templates with Packer and HashiCorp Vault](https://blog.jlab.systems/posts/build-ubuntu-noble-template-with-packer/)

---

**Last Updated**: 2025-12-24
**Maintained By**: Personal homelab automation
