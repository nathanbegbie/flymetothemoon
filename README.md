# Flymetothemoon

A self-hosted Elixir Phoenix application deployment guide for Hetzner Cloud with automated CI/CD.

## Project Goals

1. Demonstrate easy setup with a local setup script
2. Provision a server on Hetzner using OpenTofu
3. Set up a straightforward CI/CD pipeline with GitHub Actions

**Stretch Goals:**
- Automatic backups
- Automated or Semi-Automated Upgrades of Elixir/Erlang
- Playbooks for increasing or decreasing resources on Hetzner with minimal downtime
- Automatic DNS setup

## Motivation

Managing infrastructure on self-hosted servers provides more control and transferable skills compared to platform-specific PaaS solutions. With coding agents reducing the complexity of Infrastructure as Code (IaC) and deployment scripts, this approach becomes viable for side projects that need long-term stability without vendor lock-in.

---

## Complete Setup Guide

This guide walks you through the entire infrastructure setup and deployment process, from local development to production deployment on Hetzner Cloud.

### Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Infrastructure Provisioning with OpenTofu](#infrastructure-provisioning-with-opentofu)
4. [Server Configuration](#server-configuration)
5. [Application Deployment Setup](#application-deployment-setup)
6. [CI/CD Pipeline with GitHub Actions](#cicd-pipeline-with-github-actions)
7. [DNS Configuration](#dns-configuration)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

- **Local machine:**
  - Git installed
  - Elixir/Erlang installed (see `.tool-versions` for versions)
  - Docker installed (for testing builds locally)
  - OpenTofu or Terraform installed

- **Accounts:**
  - GitHub account (for repository and CI/CD)
  - Hetzner Cloud account (for hosting)

- **SSH key:**
  - An SSH key pair at `~/.ssh/id_rsa` (or `~/.ssh/id_ed25519`)
  - If you don't have one: `ssh-keygen -t ed25519 -C "your-email@example.com"`

---

## Local Development Setup

**⚠️ GAP: Local setup script not yet implemented**

The project aims to have an automated local setup script. For now, manual setup is required:

```bash
# Clone the repository
git clone https://github.com/yourusername/flymetothemoon.git
cd flymetothemoon

# Install dependencies
mix deps.get

# Set up database (if running locally)
mix ecto.setup

# Start the Phoenix server
mix phx.server
```

Visit `http://localhost:4000` to verify the application runs locally.

---

## Infrastructure Provisioning with OpenTofu

### Step 1: Install OpenTofu

```bash
# macOS
brew install opentofu

# Or use Terraform if you prefer
brew install terraform
```

### Step 2: Get Hetzner API Token

1. Visit https://console.hetzner.cloud
2. Create or select a project
3. Navigate to **Access** → **API Tokens**
4. Click **Generate API Token** with **Read & Write** permissions
5. Save the token securely

### Step 3: Configure OpenTofu Variables

```bash
cd infra/tofu

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and add your Hetzner API token
# Also customize server_name, server_type, location as needed
```

Example `terraform.tfvars`:
```hcl
hcloud_token = "your-actual-api-token-here"
server_name  = "flymetothemoon-prod"
server_type  = "cx22"  # 2 vCPU, 4GB RAM (~€5.83/month)
location     = "nbg1"  # Nuremberg, Germany
image        = "ubuntu-24.04"
```

**Server Type Options:**
- `cx22`: 2 vCPU, 4GB RAM, 40GB disk (~€5.83/month)
- `cx32`: 4 vCPU, 8GB RAM, 80GB disk (~€11.66/month)
- `cpx21`: 3 vCPU, 4GB RAM, 80GB disk (~€7.63/month)
- `cax11`: 2 vCPU ARM, 4GB RAM, 40GB disk (~€4.15/month)

See pricing: https://www.hetzner.com/cloud

**Location Options:**
- `nbg1`: Nuremberg, Germany
- `fsn1`: Falkenstein, Germany
- `hel1`: Helsinki, Finland
- `ash`: Ashburn, USA
- `hil`: Hillsboro, USA

### Step 4: Deploy Infrastructure

```bash
# Initialize OpenTofu (downloads providers)
tofu init

# Preview changes
tofu plan

# Apply configuration
tofu apply
```

Type `yes` when prompted.

### Step 5: Get Server IP Address

```bash
# View all outputs
tofu output

# Get just the IP address
tofu output -raw server_ipv4
```

Save this IP address - you'll need it for DNS configuration and GitHub secrets.

**Infrastructure Created:**
- Ubuntu 24.04 LTS server with Docker pre-installed
- Firewall rules (SSH:22, HTTP:80, HTTPS:443, Phoenix:4000)
- Your personal SSH key configured for root access

---

## Server Configuration

### Step 1: Connect to Your Server

```bash
ssh root@$(tofu output -raw server_ipv4)
```

### Step 2: Create Deployment User

Create a dedicated user for GitHub Actions deployments (principle of least privilege):

```bash
# Create the deploy user
useradd -m -s /bin/bash github-deploy

# Add to docker group
usermod -aG docker github-deploy

# Set up SSH directory
mkdir -p /home/github-deploy/.ssh
chmod 700 /home/github-deploy/.ssh
touch /home/github-deploy/.ssh/authorized_keys
chmod 600 /home/github-deploy/.ssh/authorized_keys
chown -R github-deploy:github-deploy /home/github-deploy/.ssh
```

### Step 3: Generate GitHub Actions Deploy Key

On your **local machine**, generate a dedicated SSH key for GitHub Actions:

```bash
# Generate a new ED25519 key
ssh-keygen -t ed25519 -f ~/.ssh/flymetothemoon_deploy -C "github-deploy"

# Display the public key
cat ~/.ssh/flymetothemoon_deploy.pub
```

Copy the public key output.

### Step 4: Add Deploy Key to Server

Back on your **server** (as root):

```bash
# Paste the public key into authorized_keys
nano /home/github-deploy/.ssh/authorized_keys
# Paste the key, save and exit (Ctrl+X, Y, Enter)
```

Or from your **local machine**:

```bash
cat ~/.ssh/flymetothemoon_deploy.pub | ssh root@$(cd infra/tofu && tofu output -raw server_ipv4) "cat >> /home/github-deploy/.ssh/authorized_keys"
```

### Step 5: Test Deploy Key

From your **local machine**:

```bash
ssh -i ~/.ssh/flymetothemoon_deploy github-deploy@$(cd infra/tofu && tofu output -raw server_ipv4)
```

If successful, you should be logged in as `github-deploy`. Type `exit` to disconnect.

### Step 6: Run Server Setup Script

On your **server** (as root):

```bash
# Download and run the setup script
curl -fsSL https://raw.githubusercontent.com/yourusername/flymetothemoon/main/infra/scripts/setup-server.sh -o setup-server.sh
chmod +x setup-server.sh
./setup-server.sh

# Or if you've cloned the repo on the server:
cd /tmp
git clone https://github.com/yourusername/flymetothemoon.git
chmod +x flymetothemoon/infra/scripts/setup-server.sh
./flymetothemoon/infra/scripts/setup-server.sh
```

This script creates:
- `/opt/flymetothemoon/` directory structure
- `docker-compose.yml` for the application stack
- `Caddyfile` for reverse proxy and SSL
- `.env.example` template

### Step 7: Configure Environment Variables

```bash
cd /opt/flymetothemoon

# Copy the example file
cp .env.example .env

# Generate a secret key base (run this on your local machine with Elixir installed)
# mix phx.gen.secret

# Edit .env with real values
nano .env
```

Required variables:
```bash
GITHUB_USERNAME=your-github-username
GITHUB_REPO=flymetothemoon

PHX_HOST=your-domain.com
SECRET_KEY_BASE=<output-from-mix-phx-gen-secret>

DB_NAME=flymetothemoon_prod
DB_USER=flymetothemoon
DB_PASSWORD=<generate-strong-password>
```

### Step 8: Update Caddyfile with Your Domain

```bash
nano /opt/flymetothemoon/caddy/Caddyfile
```

Replace `your-domain.com` with your actual domain and `your-email@example.com` with your email for Let's Encrypt certificates.

### Step 9: Set Proper Permissions

```bash
# Make github-deploy user own the application directory
chown -R github-deploy:github-deploy /opt/flymetothemoon

# Allow github-deploy to restart docker containers
usermod -aG docker github-deploy
```

---

## Application Deployment Setup

**⚠️ GAP: Initial manual deployment process**

Before GitHub Actions can deploy automatically, you need to pull and start the application once manually.

### Option A: Deploy Manually First

After building and pushing your Docker image to GitHub Container Registry manually:

```bash
# As github-deploy user on the server
ssh github-deploy@<server-ip>
cd /opt/flymetothemoon

# Log in to GitHub Container Registry
echo $GITHUB_PAT | docker login ghcr.io -u <your-github-username> --password-stdin

# Pull the image
docker compose pull app

# Run database migrations (first time only)
docker compose run --rm app /app/bin/flymetothemoon eval "Flymetothemoon.Release.migrate"

# Start services
docker compose up -d

# Check logs
docker compose logs -f app
```

**⚠️ GAP: Database migration automation**

Currently, database migrations must be run manually on first deployment or after schema changes. Consider adding a migration step to the deployment process.

### Option B: Use GitHub Actions from the Start

If you've configured GitHub Actions secrets (see next section), push to main branch and let CI/CD handle the deployment.

---

## CI/CD Pipeline with GitHub Actions

The repository includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) that:
1. Builds a Docker image on every push to `main`
2. Pushes the image to GitHub Container Registry
3. Deploys to your Hetzner server via SSH

### Step 1: Make Container Registry Public (or Authenticate)

**Option A: Make the package public** (easier for side projects)

1. Go to your GitHub repository
2. Navigate to **Packages** → **flymetothemoon**
3. Click **Package settings**
4. Under **Danger Zone**, change visibility to **Public**

**Option B: Use authentication** (more secure)

**⚠️ GAP: Server authentication to private GitHub Container Registry**

You'll need to configure the server to authenticate with GitHub Container Registry using a Personal Access Token with `read:packages` scope.

### Step 2: Configure GitHub Secrets

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets:

**SSH_PRIVATE_KEY**:
```bash
# On your local machine, copy the deploy key private key
cat ~/.ssh/flymetothemoon_deploy
# Copy the entire output including -----BEGIN and -----END lines
```

**SSH_HOST**:
```bash
# Get your server IP
cd infra/tofu && tofu output -raw server_ipv4
# Paste this IP address as the secret value
```

**SSH_USER**:
```
github-deploy
```

### Step 3: Test the Deployment

```bash
# Make a small change to trigger deployment
git commit --allow-empty -m "Test deployment"
git push origin main
```

Go to **Actions** tab in GitHub to watch the deployment progress.

### Platform Compatibility Note

The current `.github/workflows/deploy.yml` builds for `linux/arm64` architecture. Ensure your Hetzner server type is ARM-based (`cax` series), or update the workflow to match your architecture:

```yaml
# For Intel/AMD servers (cx, cpx series):
platforms: linux/amd64

# For ARM servers (cax series):
platforms: linux/arm64
```

---

## DNS Configuration

**⚠️ GAP: Automatic DNS setup not yet implemented**

Manual DNS configuration is required:

1. Log in to your domain registrar or DNS provider
2. Add an **A record**:
   - Name: `@` (or your subdomain, e.g., `app`)
   - Type: `A`
   - Value: `<your-server-ip-from-tofu-output>`
   - TTL: `3600` (or default)

3. Wait for DNS propagation (can take 5 minutes to 48 hours)

4. Verify DNS is working:
   ```bash
   nslookup your-domain.com
   # Should show your server IP
   ```

5. Once DNS is working, Caddy will automatically obtain SSL certificates from Let's Encrypt

**Future Enhancement:**
- Automate DNS configuration using Terraform providers (e.g., Cloudflare, Route53)
- Add DNS validation to the setup script

---

## Monitoring and Maintenance

**⚠️ GAP: Application monitoring not yet implemented**

Consider adding:
- Health check endpoints in the Phoenix application
- Uptime monitoring (e.g., UptimeRobot, Healthchecks.io)
- Log aggregation and error tracking (e.g., Sentry, LogTail)
- Server metrics monitoring (e.g., Netdata, Prometheus)

### View Application Logs

```bash
ssh github-deploy@<server-ip>
cd /opt/flymetothemoon
docker compose logs -f app
```

### Restart Services

```bash
docker compose restart app
# or
docker compose down && docker compose up -d
```

---

## Backups

**⚠️ GAP: Automatic backups not yet implemented**

Manual backup process:

```bash
# Backup database
docker compose exec postgres pg_dump -U flymetothemoon flymetothemoon_prod > backup_$(date +%Y%m%d).sql

# Or from local machine
ssh github-deploy@<server-ip> "cd /opt/flymetothemoon && docker compose exec -T postgres pg_dump -U flymetothemoon flymetothemoon_prod" > backup_$(date +%Y%m%d).sql
```

**Future Enhancement:**
- Automated daily database backups
- Backup to external storage (S3, Backblaze B2)
- Hetzner Cloud volume backups

---

## Upgrading Elixir/Erlang

**⚠️ GAP: Automated version upgrades not yet implemented**

Manual process:

1. Update `Dockerfile` with new Elixir/Erlang versions
2. Update `.tool-versions` locally
3. Test locally
4. Push to trigger CI/CD rebuild
5. Deploy

**Future Enhancement:**
- Semi-automated upgrade scripts
- Testing matrix for multiple Elixir/Erlang versions

---

## Scaling Resources

**⚠️ GAP: Resource scaling playbooks not yet implemented**

Manual process to upgrade server size:

1. Create a snapshot of your current server in Hetzner Console
2. Update `server_type` in `infra/tofu/terraform.tfvars`
3. Run `tofu apply` (will recreate the server)
4. Restore data from snapshot or backup
5. Update DNS if IP changed

**Future Enhancement:**
- Playbooks for zero-downtime scaling
- Vertical scaling automation
- Horizontal scaling with load balancer

---

## Troubleshooting

### Cannot connect to server via SSH

```bash
# Check if server is running
cd infra/tofu && tofu output

# Check firewall status
ssh root@<server-ip>
ufw status

# Check SSH service
systemctl status ssh
```

### Docker container won't start

```bash
# Check logs
docker compose logs app

# Check environment variables
docker compose config

# Verify database is running
docker compose ps
```

### SSL certificates not working

```bash
# Check Caddy logs
docker compose logs caddy

# Verify DNS is pointing to correct IP
nslookup your-domain.com

# Manually trigger certificate request
docker compose restart caddy
```

### GitHub Actions deployment fails

- Verify SSH_PRIVATE_KEY, SSH_HOST, and SSH_USER secrets are correct
- Check that github-deploy user has docker group access
- Verify `/opt/flymetothemoon` directory exists and has correct permissions
- Check Actions logs for specific error messages

### Database connection errors

```bash
# Check database is running
docker compose ps postgres

# Check database logs
docker compose logs postgres

# Verify DATABASE_URL in .env matches docker-compose.yml
```

---

## Security Best Practices

1. **SSH Key Management:**
   - Personal key for server administration
   - Separate deploy key for CI/CD
   - Never share private keys

2. **Secrets:**
   - Never commit `terraform.tfvars` or `.env` files
   - Rotate secrets periodically
   - Use strong, random passwords

3. **Firewall:**
   - Restrict SSH to specific IPs if possible (edit `infra/tofu/main.tf`)
   - Keep only necessary ports open

4. **Updates:**
   - Regularly update server packages: `apt update && apt upgrade`
   - Keep Docker images updated
   - Monitor security advisories for Elixir/Phoenix

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│           Internet Traffic              │
└──────────────┬──────────────────────────┘
               │
       ┌───────▼────────┐
       │  Hetzner Cloud │
       │   Server       │
       │  (Ubuntu 24.04)│
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │     Caddy      │  ← Reverse proxy + SSL
       │   (Container)  │
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │  Phoenix App   │  ← Elixir application
       │   (Container)  │
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │   PostgreSQL   │  ← Database
       │   (Container)  │
       └────────────────┘
```

**CI/CD Flow:**
```
Local Git Push → GitHub → Actions Build → GHCR → SSH Deploy → Server
```

---

## Resources

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Hetzner Cloud Documentation](https://docs.hetzner.com/cloud/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

## Contributing

This is a personal project demonstrating self-hosted infrastructure. Feel free to fork and adapt for your own use.

---

## License

**⚠️ GAP: License not specified**

Consider adding a LICENSE file (MIT, Apache 2.0, etc.)
