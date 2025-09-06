#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}
888b      88               88           88
8888b     88               88           ""    ,d
88 \`8b    88               88                 88
88  \`8b   88   ,adPPYba,   88,dPPYba,   88  MM88MMM  ,adPPYYba,
88   \`8b  88  a8\"     \"8a  88P'    \"8a  88    88     \"\"     \`Y8
88    \`8b 88  8b       d8  88       d8  88    88     ,adPPPPP88
88     \`8888  \"8a,   ,a8\"  88b,   ,a8\"  88    88,    88,    ,88
88      \`888   \`\"YbbdP\"'   8Y\"Ybbd8\"'   88    \"Y888  \`\"8bbdP\"Y8
${NC}"

read -p "Enter your domain (e.g., panel.example.com): " DOMAIN

echo "🔍 Installing dependencies..."
apt update && apt install -y curl unzip git software-properties-common apt-transport-https ca-certificates gnupg

# Add PHP repo & Redis
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
apt update

echo "🔍 Installing PHP, MariaDB, Redis, and other tools..."
apt -y install php8.3 php8.3-{cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server unzip composer

# Check PHP extensions
MISSING_EXT=false
for ext in pdo_mysql zip simplexml dom; do
  if ! php -m | grep -qi "$ext"; then
    echo -e "${RED}❌ Missing PHP extension: $ext${NC}"
    MISSING_EXT=true
  fi
done
if [ "$MISSING_EXT" = true ]; then
  echo -e "${GREEN}✅ Installing missing extensions...${NC}"
  apt install -y php8.3-mysql php8.3-xml php8.3-zip php8.3-mbstring
fi

echo "✅ All extensions installed."

# Create directory
mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl

# Download panel
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Database setup
DB_NAME="panel"
DB_USER="pterodactyl"
DB_PASS=$(openssl rand -base64 12)
mariadb -e "CREATE DATABASE $DB_NAME;"
mariadb -e "CREATE USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'127.0.0.1'; FLUSH PRIVILEGES;"

# .env setup
[ ! -f ".env.example" ] && curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" .env

# Composer install
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader || {
    echo -e "${RED}Composer failed! Retrying...${NC}"
    composer update --no-dev --optimize-autoloader
}

# Generate key
php artisan key:generate --force || {
    echo "Retrying key generation..."
    php artisan key:generate --force
}

# Run migrations
php artisan migrate --seed --force

# Permissions
chown -R www-data:www-data /var/www/pterodactyl/*
chmod -R 755 /var/www/pterodactyl/storage /var/www/pterodactyl/bootstrap/cache

# Cron job
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# NGINX config
tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
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

mkdir -p /etc/certs/panel
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=$DOMAIN" \
-keyout /etc/certs/panel/privkey.pem -out /etc/certs/panel/fullchain.pem

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Queue worker
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
systemctl enable --now redis-server pteroq.service

php artisan p:user:make

echo -e "${GREEN}✅ Pterodactyl setup complete!${NC}"
echo -e "URL: https://$DOMAIN"
echo -e "DB USER: $DB_USER | DB PASS: $DB_PASS"
