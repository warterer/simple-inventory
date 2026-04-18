#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Start script with sudo: sudo ./setup.sh"
  exit 1
fi

echo "Start configuring Simple Inventory (N=20)"

apt-get update
apt-get install -y nginx mariadb-server curl

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

DB_NAME="inventory_db"
DB_USER="app"
DB_PASS="12345678"

mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';"
mysql -e "FLUSH PRIVILEGES;"

if ! id "student" &>/dev/null; then 
    useradd -m -s /bin/bash -G sudo student
    echo "student:12345678" | chpasswd
fi

if ! id "teacher" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo teacher
    echo "teacher:12345678" | chpasswd
    chage -d 0 teacher
fi

if ! id "app" &>/dev/null; then useradd -r -s /bin/false app; fi

if ! id "operator" &>/dev/null; then
    getent group operator || groupadd operator
    useradd -m -s /bin/bash -g operator operator
    echo "operator:12345678" | chpasswd
    chage -d 0 operator
fi

cat <<EOF > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx
EOF
chmod 440 /etc/sudoers.d/operator

APP_DIR="/opt/mywebapp"
mkdir -p ${APP_DIR}
cp -r ./* ${APP_DIR}/
cd ${APP_DIR}
npm install
chown -R app:app ${APP_DIR}

cat <<EOF > /etc/systemd/system/mywebapp.socket
[Unit]
Description=MyWebApp Socket

[Socket]
ListenStream=127.0.0.1:8080

[Install]
WantedBy=sockets.target
EOF

cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=MyWebApp Simple Inventory Service
Requires=mywebapp.socket
After=network.target mariadb.service

[Service]
Type=simple
User=app
WorkingDirectory=${APP_DIR}
Environment=NODE_ENV=production
ExecStartPre=/usr/bin/node ${APP_DIR}/migrate.js --db_user=${DB_USER} --db_pass=${DB_PASS} --db_name=${DB_NAME}
ExecStart=/usr/bin/node ${APP_DIR}/app.js --db_user=${DB_USER} --db_pass=${DB_PASS} --db_name=${DB_NAME}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mywebapp.socket

cat <<EOF > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;

    location = / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
    }

    location /items {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
    }

    location / {
        return 404;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
systemctl restart nginx

echo "20" > /home/student/gradebook
chown student:student /home/student/gradebook

DEFAULT_USER=$(id -un 1000)
if [ -n "$DEFAULT_USER" ] && [ "$DEFAULT_USER" != "student" ]; then
    usermod -L $DEFAULT_USER
    echo "User $DEFAULT_USER has been locked."
fi

echo "Setup successfully completed!"