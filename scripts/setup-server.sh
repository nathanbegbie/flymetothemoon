#!/bin/bash
set -e

echo "=== Flymetothemoon Server Setup ==="

APP_DIR="/opt/flymetothemoon"

# Create directory structure
echo "Creating directories..."
mkdir -p $APP_DIR/{caddy,postgres/data}
cd $APP_DIR

# Create Caddyfile
echo "Creating Caddyfile..."
cat > $APP_DIR/caddy/Caddyfile <<'EOF'
{
    email your-email@example.com
}

your-domain.com {
    reverse_proxy app:4000

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }

    log {
        output file /data/access.log {
            roll_size 100mb
            roll_keep 10
        }
    }

    encode gzip
}
EOF

# Create docker-compose.yml
echo "Creating docker-compose.yml..."
cat > $APP_DIR/docker-compose.yml <<'EOF'
version: '3.8'

services:
  caddy:
    image: caddy:2-alpine
    container_name: flymetothemoon-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy/data:/data
      - ./caddy/config:/config
    networks:
      - web
    depends_on:
      - app

  postgres:
    image: postgres:16-alpine
    container_name: flymetothemoon-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME:-flymetothemoon_prod}
      POSTGRES_USER: ${DB_USER:-flymetothemoon}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-flymetothemoon}"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: ghcr.io/${GITHUB_USERNAME}/${GITHUB_REPO}:latest
    container_name: flymetothemoon-app
    restart: unless-stopped
    environment:
      PHX_SERVER: "true"
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST}
      PORT: "4000"
      DATABASE_URL: "ecto://${DB_USER:-flymetothemoon}:${DB_PASSWORD}@postgres:5432/${DB_NAME:-flymetothemoon_prod}"
    networks:
      - web
      - backend
    depends_on:
      postgres:
        condition: service_healthy

networks:
  web:
    driver: bridge
  backend:
    driver: bridge
EOF

# Create .env template
echo "Creating .env.example..."
cat > $APP_DIR/.env.example <<EOF
GITHUB_USERNAME=your-github-username
GITHUB_REPO=flymetothemoon

PHX_HOST=your-domain.com
SECRET_KEY_BASE=generate-with-mix-phx-gen-secret

DB_NAME=flymetothemoon_prod
DB_USER=flymetothemoon
DB_PASSWORD=generate-strong-password
EOF

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy .env.example to .env and fill in real values"
echo "2. Generate SECRET_KEY_BASE: mix phx.gen.secret (run locally)"
echo "3. Update Caddyfile with your domain and email"
echo "4. Update .env with your GitHub username/repo"
