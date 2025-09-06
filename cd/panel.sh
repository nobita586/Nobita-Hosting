#!/bin/bash

# ----------------------------------
# Pterodactyl Full Master Setup Script with Fixed Banner
# ----------------------------------

# Banner
GREEN='\033[0;32m'
NC='\033[0m'
cat << EOF
${GREEN}
888b      88               88           88
8888b     88               88           ""    ,d
88 \`8b    88               88                 88
88  \`8b   88   ,adPPYba,   88,dPPYba,   88  MM88MMM  ,adPPYYba,
88   \`8b  88  a8"     "8a  88P'    "8a  88    88     ""     \`Y8
88    \`8b 88  8b       d8  88       d8  88    88     ,adPPPPP88
88     \`8888  "8a,   ,a8"  88b,   ,a8"  88    88,    88,    ,88
88      \`888   \`"YbbdP"'   8Y"Ybbd8"'   88    "Y888  \`"8bbdP"Y8
${NC}
EOF

# Ask for domain
read -p "Enter your domain (e.g., panel.example.com): " DOMAIN

# --- Install Dependencies ---
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
apt update
apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# --- Download Pterodactyl Panel ---
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# --- Setup MariaDB ---
DB_NAME=panel
DB_USER=pterodactyl
DB_PASS=yourPassword
sudo mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
sudo mariadb -e "CREATE DATABASE ${DB_NAME};"
sudo mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
sudo mariadb -e "FLUSH PRIVILEGES;"

# --- Create .env ---
if [ ! -f ".env.example" ]; then
    echo ".env.example not found, downloading..."
    curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
fi

cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env
if ! grep -q "^APP_ENVIRONMENT_ONLY=" .env; then
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
fi

# --- Install Dependencies for Laravel ---
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# --- Generate Encryption Key (Fix) ---
php artisan key:generate --force

# --- Run Migrations ---
php artisan migrate --seed --force

# --- Set Permissions ---
chown -R www-data:www-data /var/www/pterodactyl/*
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# --- Setup Queue Worker ---
sudo tee /etc/systemd/system/pteroq.service > /dev/null << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now redis-server
sudo systemctl enable --now pteroq.service

# --- Setup NGINX ---
sudo mkdir -p /etc/certs/panel
cd /etc/certs/panel
sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

sudo tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    ssl_certificate /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
sudo nginx -t && sudo systemctl restart nginx

# --- Create Admin User ---
php artisan p:user:make

echo "✅ Pterodactyl Panel setup complete!"
echo "URL: https://${DOMAIN}"
echo "DB: ${DB_NAME}, User: ${DB_USER}"
