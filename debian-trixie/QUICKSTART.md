# Quick Start - Debian Trixie Template

Build a Debian Trixie base template in 4 steps.

## Step 1: Verify Vault Secrets

Ensure HashiCorp Vault has the required secrets:

```bash
vault kv get kv/proxmox
```

Required keys:
- `api_url`, `api_token_id`, `api_token_secret`
- `default_user`, `default_user_ssh_key`, `default_user_ssh_pass`, `default_user_password_hash`
- `ansible_user`, `ansible_user_ssh_key`, `ansible_user_ssh_pass`, `ansible_user_password_hash`

## Step 2: Set Vault Environment

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="your-vault-token"
```

## Step 3: Initialize Packer

```bash
cd debian-trixie/packer
packer init .
```

## Step 4: Build Template

```bash
packer build .
```

## Done!

Template will be created with auto-assigned VM ID on your Proxmox node.

## Customize Build

```bash
# Use different node
packer build -var 'proxmox_node=pve-node02' .

# Custom VM ID and name
packer build -var 'vm_id=9002' -var 'vm_name=debian-custom' .

# More resources
packer build -var 'cpu_cores=4' -var 'memory=4096' .
```

## Verify Build

```bash
# Check template exists
ssh root@proxmox-server "qm list | grep debian"

# View template details
ssh root@proxmox-server "qm config VMID"
```

## Clone Template

```bash
# Clone to new VM
qm clone TEMPLATE_ID 201 --name debian-test --full

# Configure cloud-init
qm set 201 --ciuser myuser --sshkeys ~/.ssh/id_rsa.pub
qm set 201 --ipconfig0 ip=192.168.1.201/24,gw=192.168.1.1

# Start VM
qm start 201
```

## Troubleshooting

### "ISO download failed"
```bash
# Check Proxmox internet access
ssh root@proxmox-server "ping -c 2 cdimage.debian.org"

# Check storage
ssh root@proxmox-server "pvesm status"
```

### "Cannot connect to Vault"
```bash
# Verify Vault is accessible
curl -k https://vault.example.com:8200/v1/sys/health

# Check token
vault token lookup
```

### "Build hangs at boot"
- Press Ctrl+C and retry
- Check Proxmox console to see boot screen
- Verify boot_command in debian-template.pkr.hcl

## Next Steps

- Review full [README.md](README.md) for details
- Customize partition schema in `http/preseed.cfg.pkrtpl`
- Modify provisioners in `debian-template.pkr.hcl`
- Create Terraform configs to deploy VMs from this template
