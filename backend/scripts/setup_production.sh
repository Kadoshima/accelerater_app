#!/bin/bash

# Production setup script for Research Platform Backend
# This script configures the production environment with SakuraVPS domain

set -e

# Configuration
DOMAIN="os3-378-22222.vs.sakura.ne.jp"
PROJECT_DIR="/home/research/research-platform/backend"

echo "=== Research Platform Production Setup ==="
echo "Domain: $DOMAIN"
echo "Project Directory: $PROJECT_DIR"
echo ""

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Check if .env already exists
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "Warning: .env file already exists. Backing up to .env.backup"
    cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup"
fi

# Create .env file from template
echo "Creating .env file with secure passwords..."
cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"

# Generate secure passwords
POSTGRES_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
KEYCLOAK_ADMIN_PASSWORD=$(generate_password)
KEYCLOAK_DB_PASSWORD=$(generate_password)
KEYCLOAK_CLIENT_SECRET=$(generate_password)
SECRET_KEY=$(generate_password)
JWT_SECRET=$(generate_password)
MINIO_PASSWORD=$(generate_password)
GRAFANA_PASSWORD=$(generate_password)

# Update .env file with generated passwords and domain
sed -i "s|DOMAIN_NAME=.*|DOMAIN_NAME=$DOMAIN|g" "$PROJECT_DIR/.env"
sed -i "s|API_URL=.*|API_URL=https://$DOMAIN/api/v1|g" "$PROJECT_DIR/.env"
sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|g" "$PROJECT_DIR/.env"
sed -i "s|WEBSOCKET_URL=.*|WEBSOCKET_URL=wss://$DOMAIN/ws|g" "$PROJECT_DIR/.env"
sed -i "s|KEYCLOAK_PUBLIC_URL=.*|KEYCLOAK_PUBLIC_URL=https://$DOMAIN/auth|g" "$PROJECT_DIR/.env"
sed -i "s|CORS_ORIGINS=.*|CORS_ORIGINS=https://$DOMAIN,http://localhost:3000|g" "$PROJECT_DIR/.env"

sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" "$PROJECT_DIR/.env"
sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|g" "$PROJECT_DIR/.env"
sed -i "s|KEYCLOAK_ADMIN_PASSWORD=.*|KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD|g" "$PROJECT_DIR/.env"
sed -i "s|KEYCLOAK_DB_PASSWORD=.*|KEYCLOAK_DB_PASSWORD=$KEYCLOAK_DB_PASSWORD|g" "$PROJECT_DIR/.env"
sed -i "s|KEYCLOAK_CLIENT_SECRET=.*|KEYCLOAK_CLIENT_SECRET=$KEYCLOAK_CLIENT_SECRET|g" "$PROJECT_DIR/.env"
sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|g" "$PROJECT_DIR/.env"
sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|g" "$PROJECT_DIR/.env"
sed -i "s|MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$MINIO_PASSWORD|g" "$PROJECT_DIR/.env"
sed -i "s|GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD|g" "$PROJECT_DIR/.env"

# Set production environment
sed -i "s|ENVIRONMENT=.*|ENVIRONMENT=production|g" "$PROJECT_DIR/.env"
sed -i "s|LOG_LEVEL=.*|LOG_LEVEL=WARNING|g" "$PROJECT_DIR/.env"

echo "✓ Environment file created with secure passwords"

# Create necessary directories
echo "Creating required directories..."
mkdir -p "$PROJECT_DIR/nginx/ssl"
mkdir -p "$PROJECT_DIR/data/"{postgres,redis,minio}
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/backups"

echo "✓ Directories created"

# SSL Certificate setup
echo ""
echo "=== SSL Certificate Setup ==="
echo "Run the following command to obtain SSL certificate:"
echo "sudo certbot certonly --standalone -d $DOMAIN"
echo ""
echo "After obtaining the certificate, copy it to the project:"
echo "sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $PROJECT_DIR/nginx/ssl/cert.pem"
echo "sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $PROJECT_DIR/nginx/ssl/key.pem"
echo "sudo chown $(whoami):$(whoami) $PROJECT_DIR/nginx/ssl/*"
echo ""

# Update Nginx configuration for production
echo "Updating Nginx configuration..."
sed -i "s|server_name .*;|server_name $DOMAIN;|g" "$PROJECT_DIR/nginx/conf.d/default.conf"

# Enable HTTPS redirect in Nginx
sed -i "s|# if (\$host = .*|if (\$host = $DOMAIN) {|g" "$PROJECT_DIR/nginx/conf.d/default.conf"
sed -i "s|#     return 301|    return 301|g" "$PROJECT_DIR/nginx/conf.d/default.conf"

echo "✓ Nginx configuration updated"

# Create docker-compose production override
cat > "$PROJECT_DIR/docker-compose.prod.yml" << EOF
version: '3.9'

services:
  nginx:
    restart: always
    ports:
      - "80:80"
      - "443:443"

  api:
    restart: always
    environment:
      ENVIRONMENT: production
      LOG_LEVEL: WARNING
    command: gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

  postgres:
    restart: always
    volumes:
      - /data/postgres:/var/lib/postgresql/data

  redis:
    restart: always
    volumes:
      - /data/redis:/data

  celery_worker:
    restart: always
    deploy:
      replicas: 2

  minio:
    restart: always
    volumes:
      - /data/minio:/data

  keycloak:
    restart: always
    environment:
      KC_HOSTNAME: $DOMAIN
      KC_HOSTNAME_STRICT: true
      KC_HOSTNAME_STRICT_HTTPS: true
      KC_PROXY: edge
    command: start --optimized

  prometheus:
    restart: always
    ports:
      - "127.0.0.1:9090:9090"

  grafana:
    restart: always
    ports:
      - "127.0.0.1:3000:3000"
EOF

echo "✓ Production docker-compose override created"

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/research-platform.service > /dev/null << EOF
[Unit]
Description=Research Platform Backend
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose down
User=$(whoami)
Group=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable research-platform.service

echo "✓ Systemd service created"

# Create backup script
cat > "$PROJECT_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/data/backups"
mkdir -p $BACKUP_DIR

# PostgreSQL backup
docker-compose exec -T postgres pg_dump -U postgres research_db | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# MinIO data sync (if you have mc installed)
if command -v mc &> /dev/null; then
    mc mirror research/research-data $BACKUP_DIR/minio_$DATE/
fi

# Keep only last 30 days of backups
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
find $BACKUP_DIR -type d -name "minio_*" -mtime +30 -exec rm -rf {} \;

echo "Backup completed: $DATE"
EOF

chmod +x "$PROJECT_DIR/scripts/backup.sh"

echo "✓ Backup script created"

# Final instructions
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Generated Passwords (saved in .env):"
echo "- PostgreSQL: $POSTGRES_PASSWORD"
echo "- Redis: $REDIS_PASSWORD"
echo "- Keycloak Admin: admin / $KEYCLOAK_ADMIN_PASSWORD"
echo "- MinIO: minioadmin / $MINIO_PASSWORD"
echo "- Grafana: admin / $GRAFANA_PASSWORD"
echo ""
echo "IMPORTANT: Save these passwords in a secure location!"
echo ""
echo "Next Steps:"
echo "1. Obtain SSL certificate (see commands above)"
echo "2. Start services: docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
echo "3. Run migrations: docker-compose exec api alembic upgrade head"
echo "4. Create admin user: docker-compose exec api python scripts/create_admin.py"
echo "5. Configure Keycloak at https://$DOMAIN/auth"
echo "6. Set up regular backups: crontab -e"
echo "   Add: 0 2 * * * $PROJECT_DIR/scripts/backup.sh"
echo ""
echo "Access URLs:"
echo "- API: https://$DOMAIN/api/v1"
echo "- API Docs: https://$DOMAIN/docs (disabled in production)"
echo "- Keycloak: https://$DOMAIN/auth"
echo "- WebSocket: wss://$DOMAIN/ws"
echo ""