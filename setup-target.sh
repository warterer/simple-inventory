#!/bin/bash
set -e

sudo mkdir -p /opt/mywebapp
sudo chown -R $USER:$USER /opt/mywebapp

cat << 'EOF' > /opt/mywebapp/docker-compose.yml
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: rootpassword
      MARIADB_DATABASE: inventory_db
      MARIADB_USER: app
      MARIADB_PASSWORD: "12345678"
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
    image: ghcr.io/warterer/simple-inventory/mywebapp:latest
    restart: unless-stopped
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
      - ./mywebapp.conf:/etc/nginx/conf.d/default.conf:ro
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

cat << 'EOF' > /opt/mywebapp/mywebapp.conf
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

sudo tee /etc/systemd/system/mywebapp.service > /dev/null << 'EOF'
[Unit]
Description=MyWebApp Container
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker stop mywebapp
ExecStartPre=-/usr/bin/docker rm mywebapp
ExecStart=/usr/bin/docker run --name mywebapp \
  --network inventory_net \
  -e DB_HOST=db ... \
  ghcr.io/YOUR_REPO/mywebapp:latest
ExecStop=/usr/bin/docker stop mywebapp

[Install]
WantedBy=multi-user.target 
EOF

sudo systemctl daemon-reload
sudo systemctl enable mywebapp.service

echo "Setup completed!"