# Debian 13.2.0 (Trixie) Base Template

Automated Packer template for creating Debian 13.2.0 VMs on Proxmox with HashiCorp Vault integration.

## Features

- **OS**: Debian 13.2.0 (Trixie Stable) - NetInst (~780MB)
- **ISO Download**: Automatically downloads Debian 13.2.0 netinst to Proxmox `isos-nfs` storage
- **Automation**: Fully automated installation using preseed
- **Vault Integration**: All credentials pulled from HashiCorp Vault
- **Dual Users**: Two users with sudo NOPASSWD (configurable via Vault)
- **Custom Partitioning**: LVM-based partition schema optimized for servers
- **Serial Console**: Configured for Proxmox xterm.js console
- **Cloud-Init**: Pre-configured for template cloning
- **Foreman Integration**: ATIX subscription-manager for Foreman/Katello registration
- **Pre-installed Packages**: htop, btop, tmux, vim, net-tools, dnsutils, bind9-utils, nfs-common

## Prerequisites

1. **HashiCorp Vault** with secrets at `kv/proxmox`:
   - `api_url`, `api_token_id`, `api_token_secret`
   - `default_user`, `default_user_ssh_key`, `default_user_ssh_pass`, `default_user_password_hash`
   - `ansible_user`, `ansible_user_ssh_key`, `ansible_user_ssh_pass`, `ansible_user_password_hash`

2. **Proxmox Setup**:
   - Storage pool `isos-nfs` (for ISO downloads)
   - Storage pool `local-lvm` (for VM disks, or customize via variables)
   - Network bridge `vmbr1` (or customize)

3. **Vault Authentication**:
   ```bash
   export VAULT_ADDR="https://vault.home.tzalas:8200"
   export VAULT_TOKEN="your-token"
   ```

## Quick Start

```bash
cd packer
packer init .
packer build .
```

## Custom Build

Override default values:

```bash
packer build \
  -var 'proxmox_node=hv3' \
  -var 'vm_id=9002' \
  -var 'vm_name=debian-custom' \
  -var 'cpu_cores=4' \
  -var 'memory=4096' \
  .
```

## Partition Schema

Custom LVM layout optimized for server workloads:

| Partition      | Size | Type  | Mount Point | Purpose                    |
|----------------|------|-------|-------------|----------------------------|
| /boot/efi      | 512M | fat32 | /boot/efi   | EFI System Partition       |
| /boot          | 512M | ext4  | /boot       | Boot files                 |
| vg0/root       | 10G  | ext4  | /           | Root filesystem            |
| vg0/home       | 5G   | ext4  | /home       | User home directories      |
| vg0/var        | 5G   | ext4  | /var        | Variable data              |
| vg0/var_log    | 3G   | ext4  | /var/log    | System and service logs    |
| vg0/opt        | 2G   | ext4  | /opt        | Optional software          |
| vg0/var_tmp    | 5G   | ext4  | /var/tmp    | Persistent temp files      |
| tmpfs          | 2G   | tmpfs | /tmp        | Fast RAM-based temp (exec) |
| vg0/swap       | 2G   | swap  | swap        | Swap space                 |

**Total**: 35GB minimum

## Variables

All configurable via `variables.pkr.hcl` or `-var` flags:

- `proxmox_node`: Proxmox node (default: `hv1`)
- `vm_id`: Template ID (default: `null` for Proxmox auto-allocation, or specify like `9001`)
- `vm_name`: Template name (default: `debian-trixie-base`)
- `iso_url`: Debian ISO URL (default: Debian 13.2.0 stable netinst)
- `iso_checksum`: SHA512 checksum (hardcoded for 13.2.0)
- `iso_storage_pool`: Storage for downloaded ISO (default: `isos-nfs`)
- `storage_pool`: VM disk storage (default: `local-lvm`)
- `cpu_cores`: CPU cores (default: `8`)
- `memory`: RAM in MB (default: `2048`)
- `disk_size`: Disk size (default: `35G`)
- `vlan_tag`: VLAN tag (default: `10`)
- `bridge`: Network bridge (default: `vmbr1`)

## ISO Download

The template uses `iso_download_pve = true` to download the Debian ISO directly to Proxmox storage:

- **ISO Type**: NetInst (Network Install) - ~780MB
- **URL**: `https://cdimage.debian.org/cdimage/release/13.2.0/amd64/iso-cd/debian-13.2.0-amd64-netinst.iso`
- **Checksum**: SHA512 verified (hardcoded for reproducibility)
- **Storage**: Downloaded to `isos-nfs` storage pool
- **Reusable**: ISO remains in Proxmox for future builds

### Why NetInst?
- **Smaller**: 780MB vs 4GB for full DVD
- **Current packages**: Downloads latest packages during install
- **Minimal**: Only essential packages installed
- **Faster**: Less download time and verification
- **Best practice**: Recommended for automated deployments

To use DVD ISO instead, update `iso_url` in `variables.pkr.hcl`

## Post-Build

After successful build:

1. Template appears in Proxmox with auto-allocated VM ID (or custom ID if specified)
2. Template is stopped and ready for cloning
3. Manifest created: `packer/manifest.json` (contains actual VM ID assigned)

## Cloning Template

From Proxmox CLI (replace `<TEMPLATE_ID>` with actual VM ID from manifest):

```bash
# Check manifest for actual VM ID
cat packer/manifest.json | jq '.builds[0].custom_data.vm_id'

# Clone template (example with VM ID 9001)
qm clone <TEMPLATE_ID> 201 --name debian-vm-01 --full
qm set 201 --ciuser your-user --sshkeys ~/.ssh/id_rsa.pub
qm set 201 --ipconfig0 ip=192.168.10.201/24,gw=192.168.10.2
qm start 201
```

## Differences from Ubuntu Template

- **Installer**: Uses Debian preseed instead of cloud-init autoinstall
- **ISO**: Downloads directly to Proxmox (vs. pre-uploaded for Ubuntu)
- **Boot Command**: Different boot parameters for Debian installer
- **Package Manager**: apt (same as Ubuntu, but different repositories)
- **Release**: Debian 13.2.0 is Trixie stable point release

## Troubleshooting

### Build fails at boot
- Check boot_command matches your Debian ISO version
- Verify HTTP server is accessible from VM: `http://192.168.10.4:8100`

### ISO download fails
- Verify Proxmox has internet access
- Check `isos-nfs` storage is writable
- Verify ISO URL is accessible

### SSH timeout
- Check users created correctly
- Verify password hashes in Vault are SHA-512
- Check network connectivity (VLAN 10)

### Permission errors
- Ensure `/tmp` allows execution (no `noexec` in preseed)
- Verify sudo NOPASSWD is configured

## Files

```
debian-trixie/
├── packer/
│   ├── debian-template.pkr.hcl     # Main Packer template
│   ├── variables.pkr.hcl            # Variable definitions
│   └── http/
│       └── preseed.cfg.pkrtpl       # Debian preseed configuration
└── README.md                        # This file
```

## Security Notes

- SSH password authentication enabled (for flexibility)
- SSH key authentication configured
- Sudo NOPASSWD for both users (adjust in Vault if needed)
- tmpfs `/tmp` allows execution (required for Packer)
- All credentials stored in HashiCorp Vault
- SHA-512 password hashes (never plaintext in configs)

## Build Time

Typical build time: 15-20 minutes
- ISO download: 3-5 minutes (first time only)
- Installation: 8-12 minutes
- Provisioning: 3-5 minutes

## Support

For issues specific to:
- **Packer**: Check Packer logs with `PACKER_LOG=1`
- **Debian**: Review preseed.cfg template
- **Vault**: Verify secret paths and permissions
- **Proxmox**: Check Proxmox logs in `/var/log/pve/`
