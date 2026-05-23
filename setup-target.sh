#!/bin/bash

set -e

if ! command -v docker &> /dev/null; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
fi

sudo mkdir -p /opt/mywebapp
sudo chown -R "$USER:$USER" /opt/mywebapp

cat > /opt/mywebapp/docker-compose.yml << 'EOF'
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${DB_NAME}
      MARIADB_USER: ${DB_USER}
      MARIADB_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - inventory_net
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: ghcr.io/${GITHUB_REPOSITORY}/mywebapp:latest
    restart: unless-stopped
    environment:
      DB_HOST: db
      DB_USER: ${DB_USER}
      DB_PASS: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - inventory_net

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - /opt/mywebapp/mywebapp.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app
    networks:
      - inventory_net

volumes:
  db_data:

networks:
  inventory_net:
    driver: bridge
EOF

cat > /opt/mywebapp/mywebapp.conf << 'EOF'
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/mywebapp_access.log;
    error_log  /var/log/nginx/mywebapp_error.log;

    location = / {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
    }

    location /items {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
    }

    location / {
        return 404;
    }
}
EOF

if [ ! -f /opt/mywebapp/.env ]; then
  cat > /opt/mywebapp/.env << EOF
DB_ROOT_PASSWORD=changeme_root
DB_NAME=inventory_db
DB_USER=app
DB_PASSWORD=changeme_app
GITHUB_REPOSITORY=your_github_username/simple-inventory
EOF
  echo "Fill in /opt/mywebapp/.env with real values before starting!"
fi

if [ -n "$GHCR_TOKEN" ]; then
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$USER" --password-stdin
else
  echo "Set GHCR_TOKEN env var to pull images from GHCR"
fi

sudo tee /etc/systemd/system/mywebapp.service > /dev/null << 'EOF'
[Unit]
Description=MyWebApp Docker Compose Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/mywebapp
EnvironmentFile=/opt/mywebapp/.env
ExecStartPre=/usr/bin/docker compose pull
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mywebapp.service

echo "Setup completed! Edit /opt/mywebapp/.env then run:"
echo "   sudo systemctl start mywebapp.service"