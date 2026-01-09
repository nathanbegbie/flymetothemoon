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

## Post-Deployment: Secure SSH Key Setup

After the server is provisioned, follow these steps to set up secure access for deployments and CI/CD.

### 1. Connect to Your Server

```bash
ssh root@$(tofu output -raw server_ipv4)
```

### 2. Create a Deployment User

Create a dedicated user for application deployments (instead of using root):

```bash
# Create the deploy user
useradd github-deploy

# Add to docker group (if using Docker)
usermod -aG docker github-deploy

# Set up SSH directory
mkdir -p /home/github-deploy/.ssh
chmod 700 /home/github-deploy/.ssh
touch /home/github-deploy/.ssh/authorized_keys
chmod 600 /home/github-deploy/.ssh/authorized_keys
chown -R github-deploy:github-deploy /home/github-deploy/.ssh
```

### 3. Configure Sudo Access (Optional)

If the deploy user needs sudo privileges:

```bash
# Add deploy user to sudo group
usermod -aG sudo deploy

# Or create a sudoers file for passwordless sudo (be careful!)
echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp" > /etc/sudoers.d/deploy
chmod 440 /etc/sudoers.d/deploy
```

### 4. Generate GitHub Actions Deploy Key

On your local machine, generate a dedicated SSH key for GitHub Actions:

```bash
# Generate a new ED25519 key (more secure than RSA)
ssh-keygen -t ed25519 -f ~/.ssh/flymetothemoon_deploy -C "github-deploy"

# This creates two files:
# ~/.ssh/flymetothemoon_deploy      (private key - for GitHub Secrets)
# ~/.ssh/flymetothemoon_deploy.pub  (public key - for server)
```

### 5. Add Deploy Key to Server

Copy the public key content:

```bash
cat ~/.ssh/flymetothemoon_deploy.pub
```

SSH into your server and add it to the deploy user's authorized_keys:

```bash
# Copy the public key directly from local machine to deploy user's authorized_keys
cat ~/.ssh/flymetothemoon_deploy.pub | ssh root@$(tofu output -raw server_ipv4) "cat >> /home/github-deploy/.ssh/authorized_keys"

```

### 6. Configure GitHub Actions

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets:

   **SSH_PRIVATE_KEY**:
   ```bash
   # Copy your private key content
   cat ~/.ssh/flymetothemoon_deploy
   ```
   
   **SSH_HOST**:
   ```bash
   # Get your server IPv4 address
   tofu output -raw server_ipv4
   ```
   
   **SSH_USER**:
   ```
   github-deploy
   ```

### 7. Test the Deploy Key

From your local machine, test the connection:

```bash
ssh -i ~/.ssh/flymetothemoon_deploy github-deploy@$(tofu output -raw server_ipv4)
```

If successful, you should be logged in as the `deploy` user (not root).

## SSH Key Security Best Practices

### Key Separation Strategy

- **Personal Key**: Used for root access and server administration
- **Deploy Key**: Used exclusively for GitHub Actions deployments
- **Never share private keys** between users or services

### Why This Approach is Safer

1. **Principle of Least Privilege**: GitHub Actions only has access to the `deploy` user, not root
2. **Easier Rotation**: Revoke/rotate the deploy key without affecting personal access
3. **Audit Trail**: Separate keys make it easier to track who accessed what
4. **Containment**: If the GitHub Actions key is compromised, root access remains secure

### Key Rotation

To rotate the deploy key:

```bash
# 1. Generate a new key
ssh-keygen -t ed25519 -f ~/.ssh/flymetothemoon_deploy_new -C "github-actions-deploy"

# 2. Add new public key to server
ssh root@$(tofu output -raw server_ipv4)
echo "ssh-ed25519 AAAA...new-key... github-actions-deploy" >> /home/deploy/.ssh/authorized_keys

# 3. Update GitHub Secret SSH_PRIVATE_KEY with new private key

# 4. Test the new key works

# 5. Remove old key from authorized_keys on server
```

## Next Steps

After completing the secure SSH setup:
1. Clone your application repository to `/home/deploy/flymetothemoon`
2. Set up environment variables
3. Deploy your Phoenix application with Docker
4. Configure your domain DNS to point to the server IP

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
