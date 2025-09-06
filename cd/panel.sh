#!/bin/bash

# ----------------------------------
# Pterodactyl Full Master Setup Script with Fixed Banner
# ----------------------------------

# Banner with color
GREEN='\033[0;32m'
NC='\033[0m' # No Color
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

# Ask for domain name once
read -p "Enter your domain (e.g., panel.example.com): " DOMAIN

# --- Panel Dependency Setup ---
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

# Copy .env and configure
if [ ! -f ".env.example" ]; then
    echo ".env.example not found, downloading fresh copy..."
    curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
fi

cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

# Add APP_ENVIRONMENT_ONLY=false
if grep -q "^APP_ENVIRONMENT_ONLY=" .env; then
    sed -i "s|^APP_ENVIRONMENT_ONLY=.*|APP_ENVIRONMENT_ONLY=false|g" .env
else
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
fi


# Install PHP dependencies and generate key
cd /var/www/pterodactyl
php artisan key:generate --force
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
# Run migrations & set permissions
php artisan migrate --seed --force
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
    return 301 \$server_name\$request_uri;
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
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
sudo nginx -t && sudo systemctl restart nginx

# --- Create Admin User ---
cd /var/www/pterodactyl
php artisan p:user:make

# --- Display Panel Info ---
echo "\nPterodactyl Panel setup complete!"
echo "Visit your panel at: https://${DOMAIN}"
echo "Your database name: ${DB_NAME}, user: ${DB_USER}"
