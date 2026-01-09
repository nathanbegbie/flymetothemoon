# Look up specific SSH keys by name
data "hcloud_ssh_key" "selected_keys" {
  for_each = toset(var.ssh_keys)
  name     = each.value
}

# Firewall to protect the server
resource "hcloud_firewall" "web_firewall" {
  name = "${var.server_name}-firewall"

  # SSH access
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # HTTP
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # HTTPS
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Phoenix default port (optional, for development/testing)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "4000"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# Main server resource
resource "hcloud_server" "app_server" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [for key in data.hcloud_ssh_key.selected_keys : key.id]
  backups     = var.enable_backups
  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }

  firewall_ids = [hcloud_firewall.web_firewall.id]

  labels = {
    app         = "flymetothemoon"
    environment = "production"
    managed_by  = "terraform"
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - docker.io
      - docker-compose
      - git
      - curl
    runcmd:
      - systemctl start docker
      - systemctl enable docker
      - usermod -aG docker root
  EOF
}
