#!/bin/bash

set -e  # Exit if any command fails

# --- Banner ---
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

read -p "Enter your domain (e.g., panel.example.com): " DOMAIN

# --- Dependencies ---
apt update && apt install -y curl unzip git composer php-cli php-mbstring php-bcmath php-
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
apt update
apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server unzip

# Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# --- Download Panel ---
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# --- MariaDB Setup ---
DB_NAME=panel
DB_USER=pterodactyl
DB_PASS=yourPassword
mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "CREATE DATABASE ${DB_NAME};"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"

# --- .env Setup ---
if [ ! -f ".env.example" ]; then
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

# --- Install Dependencies ---
echo "Installing PHP dependencies..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# --- Check vendor before artisan ---
if [ ! -d "vendor" ]; then
    echo "❌ Composer vendor folder missing! Exiting."
    exit 1
fi

# --- Generate Key (Retry if fails) ---
echo "Generating application key..."
php artisan key:generate --force || {
    echo "Retrying key generation..."
    sleep 3
    php artisan key:generate --force
}

# --- Run Migrations ---
php artisan migrate --seed --force

# --- Permissions ---
chown -R www-data:www-data /var/www/pterodactyl/*
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# --- NGINX ---
sudo mkdir -p /etc/certs/panel
cd /etc/certs/panel
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
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
}
EOF

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
nginx -t && systemctl restart nginx

# --- Queue Worker ---
tee /etc/systemd/system/pteroq.service > /dev/null << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server
systemctl enable --now pteroq.service

# --- Create Admin ---
php artisan p:user:make

echo "✅ Pterodactyl setup complete!"
echo "URL: https://${DOMAIN}"
