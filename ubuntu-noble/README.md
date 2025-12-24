# Loki VM Deployment with Packer and Terraform

This project automates the deployment of Grafana Loki log aggregation server on Proxmox using Packer for template creation and Terraform for VM provisioning. All credentials are securely managed through HashiCorp Vault.

## Overview

### Architecture

```
HashiCorp Vault (Credentials Storage)
    ↓
Packer → Build Ubuntu Template with Loki
    ↓
Proxmox (Store Template)
    ↓
Terraform → Deploy VM from Template
    ↓
Loki VM (Running on Proxmox)
```

### Components

- **Packer**: Builds a Ubuntu 24.04 VM template with Loki pre-installed
- **Terraform**: Deploys VM from template with proper configuration
- **HashiCorp Vault**: Stores all sensitive credentials and configuration
- **Proxmox**: Virtualization platform hosting the VM

## Directory Structure

```
terraform/lab/loki/
├── packer/
│   ├── loki-template.pkr.hcl       # Packer configuration
│   └── http/
│       ├── user-data               # Cloud-init autoinstall config
│       └── meta-data               # Cloud-init metadata
├── terraform/
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Variable definitions
│   ├── outputs.tf                  # Output definitions
│   └── terraform.tfvars.example    # Example variables file
├── vault-secrets-structure.md      # Vault secrets documentation
└── README.md                       # This file
```

## Prerequisites

### Required Tools

1. **Packer** (>= 1.9.0)
   ```bash
   wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
   unzip packer_1.9.4_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

2. **Terraform** (>= 1.5.0)
   ```bash
   wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
   unzip terraform_1.6.6_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

3. **HashiCorp Vault CLI**
   ```bash
   wget https://releases.hashicorp.com/vault/1.15.2/vault_1.15.2_linux_amd64.zip
   unzip vault_1.15.2_linux_amd64.zip
   sudo mv vault /usr/local/bin/
   ```

4. **Access to**:
   - Proxmox cluster (API access)
   - HashiCorp Vault instance (https://vault.home.tzalas:8200)
   - Ubuntu 24.04 ISO uploaded to Proxmox

### Infrastructure Requirements

- **Proxmox Node**: hv1.home.tzalas (or alternative)
- **Storage**: local-lvm (40GB+ available for template + VM)
- **Network**: VLAN 10 access
- **IP Address**: Reserved IP from phpIPAM or static assignment

## Setup Instructions

### Step 1: Configure Vault Secrets

See [vault-secrets-structure.md](vault-secrets-structure.md) for detailed instructions.

**Quick setup:**

```bash
export VAULT_ADDR="https://vault.home.tzalas:8200"
vault login

# Store Proxmox credentials
vault kv put kv/proxmox \
  api_url="https://hv1.internal.jlab.systems:8006/api2/json" \
  api_token_id="terraform@pve!terraform-token" \
  api_token_secret="your-secret-token" \
  pdns_api_key="your-pdns-key"

# Store network configuration
vault kv put kv/network/loki \
  ip_address="192.168.10.100" \
  gateway="192.168.10.2" \
  nameservers="10.43.44.2 10.43.44.3"

# Store SSH keys
vault kv put kv/ssh/ansible \
  public_key="$(cat ~/.ssh/ansible.pub)" \
  private_key="$(cat ~/.ssh/ansible)"
```

### Step 2: Build VM Template with Packer

**Important:** We provide three Packer configurations:
- `loki-template.pkr.hcl` - Uses environment variables (original)
- `loki-template-vault.pkr.hcl` - Vault integration for Proxmox credentials
- `loki-template-vault-complete.pkr.hcl` - **Complete Vault integration (RECOMMENDED)**

See [packer/PACKER-VAULT-GUIDE.md](packer/PACKER-VAULT-GUIDE.md) for detailed Vault integration documentation.

#### Option A: Complete Vault Integration (Recommended)

Store SSH password in Vault:
```bash
vault kv put kv/packer/loki ssh_password="TemporaryPassword123"
```

Build template:
```bash
cd packer/

# Vault authentication
export VAULT_ADDR="https://vault.home.tzalas:8200"
vault login

# Initialize and build (ALL credentials from Vault)
packer init loki-template-vault-complete.pkr.hcl
packer validate loki-template-vault-complete.pkr.hcl
packer build loki-template-vault-complete.pkr.hcl
```

#### Option B: Environment Variables (Original)

```bash
cd packer/

# Export Vault-sourced variables
export PKR_VAR_proxmox_api_url="$(vault kv get -field=api_url kv/proxmox)"
export PKR_VAR_proxmox_api_token_id="$(vault kv get -field=api_token_id kv/proxmox)"
export PKR_VAR_proxmox_api_token_secret="$(vault kv get -field=api_token_secret kv/proxmox)"
export PKR_VAR_ssh_password="temporary-password"

# Initialize Packer
packer init loki-template.pkr.hcl

# Validate configuration
packer validate loki-template.pkr.hcl

# Build template (takes ~15-20 minutes)
packer build loki-template.pkr.hcl
```

**Expected output:**
- VM template ID: 9001
- Template name: loki-template
- Location: Proxmox node hv1

### Step 3: Deploy VM with Terraform

```bash
cd ../terraform/

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy VM
terraform apply

# View outputs
terraform output
```

### Step 4: Verify Deployment

```bash
# Check VM status
terraform output vm_ip_address

# SSH to VM
ssh ansible@$(terraform output -raw vm_ip_address)

# Check Loki service
sudo systemctl status loki

# Test Loki endpoint
curl http://$(terraform output -raw vm_ip_address):3100/ready
```

## Configuration

### Terraform Variables

Key variables in `terraform.tfvars`:

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | VM hostname | `loki` |
| `vm_cores` | CPU cores | `2` |
| `vm_memory` | Memory in MB | `4096` |
| `disk_size` | OS disk size | `40G` |
| `data_disk_size` | Data disk size | `100G` |
| `vlan_tag` | Network VLAN | `10` |
| `proxmox_node` | Target Proxmox node | `hv1` |

### Packer Variables

Modify in `packer/loki-template.pkr.hcl`:

- `vm_id`: Template VM ID (default: 9001)
- `iso_file`: Ubuntu ISO location
- `proxmox_node`: Build node

## Post-Deployment Configuration

### Configure Loki

Create `/etc/loki/config.yml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v12
      index:
        prefix: index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
  filesystem:
    directory: /loki/chunks

limits_config:
  retention_period: 720h  # 30 days
```

Enable and start:

```bash
sudo systemctl enable loki
sudo systemctl start loki
```

### Configure Promtail Clients

On log sources, configure Promtail to ship logs to Loki:

```yaml
clients:
  - url: http://loki.home.tzalas:3100/loki/api/v1/push
```

### Configure Grafana

Add Loki as data source in Grafana:
- URL: `http://loki.home.tzalas:3100`
- Access: Server (default)

## Maintenance

### Update Template

```bash
cd packer/
packer build -force loki-template.pkr.hcl
```

### Scale VM Resources

```bash
cd terraform/

# Edit terraform.tfvars
vim terraform.tfvars

# Apply changes
terraform apply
```

### Destroy VM

```bash
cd terraform/
terraform destroy
```

## Troubleshooting

### Packer Build Fails

**Issue**: ISO not found
```bash
# Verify ISO exists in Proxmox
ls /var/lib/vz/template/iso/
```

**Issue**: SSH timeout
- Check VM console in Proxmox UI
- Verify cloud-init completed: `sudo cloud-init status`

### Terraform Apply Fails

**Issue**: Template not found
```bash
# Verify template exists
qm list | grep loki-template
```

**Issue**: Vault authentication
```bash
# Re-authenticate
vault login
echo $VAULT_TOKEN
```

**Issue**: IP conflict
```bash
# Check IP availability
ping 192.168.10.100
```

### Loki Not Starting

```bash
# Check logs
sudo journalctl -u loki -f

# Verify configuration
sudo loki -config.file=/etc/loki/config.yml -verify-config

# Check disk space
df -h /loki
```

## Integration with Existing Infrastructure

### Ansible Integration

Add to inventory at `inventory/hosts`:

```yaml
all:
  children:
    internal:
      children:
        unix:
          children:
            general:
              hosts:
                loki.home.tzalas:
                  ansible_host: 192.168.10.100
```

### Zabbix Monitoring

Add Loki to Zabbix:
- Template: Linux by Zabbix agent
- Custom items: Loki /ready endpoint

### PowerDNS Registration

DNS is automatically registered via Terraform if `enable_dns_registration = true`.

Manual registration:
```bash
ansible-playbook playbooks/tools/configure-pdns.yaml -e "host=loki.home.tzalas ip=192.168.10.100"
```

## Security Considerations

1. **Vault Tokens**: Use short-lived tokens, enable auto-renewal
2. **SSH Keys**: Rotate regularly, use ed25519 keys
3. **API Tokens**: Limit Proxmox token permissions to VM management only
4. **Network**: Place Loki in services VLAN (VLAN 69) for isolation
5. **Firewall**: Restrict port 3100 to trusted networks only

## References

- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/plugins/builders/proxmox/iso)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [HashiCorp Vault](https://developer.hashicorp.com/vault)

## Support

For issues:
1. Check logs: `sudo journalctl -u loki -f`
2. Verify Vault secrets: `vault kv get kv/proxmox`
3. Review Terraform state: `terraform show`
4. Check Proxmox console for VM issues

## Author

Infrastructure maintained by Konstantinos Tzalas

## Last Updated

2025-12-08
