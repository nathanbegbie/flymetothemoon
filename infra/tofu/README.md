# Hetzner Cloud Infrastructure with OpenTofu

This directory contains the OpenTofu (Terraform) configuration for deploying the Flymetothemoon application to Hetzner Cloud.

## Prerequisites

1. Install OpenTofu:
   ```bash
   # macOS
   brew install opentofu
   
   # Or use Terraform if you prefer
   brew install terraform
   ```

2. Create a Hetzner Cloud account and API token:
   - Visit https://console.hetzner.cloud
   - Create or select a project
   - Navigate to "Access" → "API Tokens"
   - Click "Generate API Token" with Read & Write permissions
   - Save the token securely

## Setup

1. Copy the example variables file:
   ```bash
   cd infra/tofu
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` and add your Hetzner API token:
   ```hcl
   hcloud_token = "your-actual-api-token-here"
   ```

3. (Optional) Customize other variables in `terraform.tfvars`:
   - `server_name`: Name for your server
   - `server_type`: Server size (cx22, cpx21, cax11, etc.)
   - `location`: Data center location (nbg1, fsn1, hel1, ash, hil)
   - `image`: OS image (ubuntu-24.04, ubuntu-22.04, etc.)

## Deployment

### Initialize OpenTofu

```bash
tofu init
# or: terraform init
```

### Plan the changes

```bash
tofu plan
# or: terraform plan
```

### Apply the configuration

```bash
tofu apply
# or: terraform apply
```

Type `yes` when prompted to confirm.

### View outputs

After successful deployment:

```bash
tofu output
# or: terraform output
```

This will show:
- Server IP address
- SSH command to connect
- Server ID and status

## Infrastructure Components

This configuration creates:

1. **Server** (`hcloud_server.app_server`):
   - Ubuntu 24.04 LTS
   - Docker and Docker Compose pre-installed
   - Your SSH key configured for access

2. **Firewall** (`hcloud_firewall.web_firewall`):
   - Port 22: SSH access
   - Port 80: HTTP
   - Port 443: HTTPS
   - Port 4000: Phoenix default port (optional, for testing)

3. **SSH Key** (`hcloud_ssh_key.default`):
   - Automatically uploads your `~/.ssh/id_rsa.pub`

## Server Types and Pricing

Common server types:
- `cx22`: 2 vCPU, 4GB RAM, 40GB disk (~€5.83/month)
- `cx32`: 4 vCPU, 8GB RAM, 80GB disk (~€11.66/month)
- `cpx21`: 3 vCPU, 4GB RAM, 80GB disk (~€7.63/month)
- `cax11`: 2 vCPU ARM, 4GB RAM, 40GB disk (~€4.15/month)

See current pricing at: https://www.hetzner.com/cloud

## Locations

Available data centers:
- `nbg1`: Nuremberg, Germany
- `fsn1`: Falkenstein, Germany
- `hel1`: Helsinki, Finland
- `ash`: Ashburn, USA
- `hil`: Hillsboro, USA

## Connecting to Your Server

After deployment, connect via SSH:

```bash
tofu output -raw ssh_command | sh
# or: ssh root@$(tofu output -raw server_ipv4)
```

## Cleaning Up

To destroy all resources:

```bash
tofu destroy
# or: terraform destroy
```

Type `yes` when prompted to confirm.

## Security Notes

- Never commit `terraform.tfvars` to version control (it contains your API token)
- The `terraform.tfvars.example` file is safe to commit
- Consider restricting SSH access to specific IPs in `main.tf` firewall rules
- Enable backups by setting `enable_backups = true` in `terraform.tfvars`

## Next Steps

After the server is provisioned:
1. SSH into the server
2. Clone your application repository
3. Set up environment variables
4. Deploy your Phoenix application with Docker

## Troubleshooting

**Error: "invalid token"**
- Check that your API token in `terraform.tfvars` is correct
- Ensure the token has Read & Write permissions

**Error: "SSH key already exists"**
- If you already have SSH keys in Hetzner, add them to the `ssh_keys` variable

**Error: "quota exceeded"**
- Check your Hetzner Cloud project limits in the console

## Resources

- [Hetzner Cloud Provider Documentation](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
