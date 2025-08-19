#!/bin/bash
set -e

# -------------------------------
# ROOT TOOL BANNER
# -------------------------------
echo ""
echo "###########################################"
echo "#                                         #"
echo "#            R O O T   T O O L            #"
echo "#                                         #"
echo "###########################################"
echo ""

# -------------------------------
# Step 0: Ask for Domain or Use IP
# -------------------------------
read -p "Enter your panel domain (leave blank to use VPS IP): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    DOMAIN="$(curl -s https://ipinfo.io/ip)"
    echo "No domain entered. Using VPS IP: $DOMAIN"
fi

# -------------------------------
# Configurable Variables
# -------------------------------
DB_NAME="panel"
DB_USER="ptero"
DB_PASS="StrongPassword123"
PANEL_VERSION="v1.11.4"
PANEL_DIR="/var/www/pterodactyl"

# -------------------------------
# Step 1: Install PHP 8.3 & Dependencies
# -------------------------------
echo "[*] Installing PHP 8.3 and dependencies..."
sudo apt update -y
sudo apt install -y software-properties-common curl
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y
sudo apt install -y nginx mariadb-server redis-server unzip git composer
sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-gd php8.3-mbstring php8.3-xml php8.3-curl php8.3-zip php8.3-bcmath php8.3-intl

sudo update-alternatives --set php /usr/bin/php8.3
sudo systemctl enable --now php8.3-fpm

# -------------------------------
# Step 2: Database Setup
# -------------------------------
echo "[*] Configuring MariaDB..."
sudo systemctl enable --now mariadb
sudo mysql -u root <<MYSQL_SCRIPT
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "[+] Database ${DB_NAME} and user ${DB_USER} created!"

# -------------------------------
# Step 3: Download & Install Panel
# -------------------------------
echo "[*] Downloading Pterodactyl Panel..."
sudo mkdir -p $PANEL_DIR
sudo chown -R $(whoami):$(whoami) $PANEL_DIR
cd $PANEL_DIR

curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL_VERSION}/panel.tar.gz -o panel.tar.gz
tar -xzvf panel.tar.gz
rm panel.tar.gz

cp .env.example .env

# Install Composer dependencies
composer install --no-dev --optimize-autoloader

# Set permissions
sudo chown -R www-data:www-data $PANEL_DIR
sudo chmod -R 755 $PANEL_DIR/storage $PANEL_DIR/bootstrap/cache

# -------------------------------
# Step 4: Generate App Key & Setup Env
# -------------------------------
echo "[*] Generating app key and setting up .env..."
php artisan key:generate --force

# Configure .env (database and app url)
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

# -------------------------------
# Step 5: Run Panel Install
# -------------------------------
php artisan migrate --seed --force

# -------------------------------
# Step 6: SSL Certificates (Generic)
# -------------------------------
echo "[*] Generating generic self-signed SSL certificate..."
sudo mkdir -p /etc/certs/panel
cd /etc/certs/panel
sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

# -------------------------------
# Step 7: Nginx Config
# -------------------------------
echo "[*] Creating Nginx config..."
sudo bash -c "cat > /etc/nginx/sites-available/pterodactyl.conf" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root ${PANEL_DIR}/public;

    ssl_certificate     /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
sudo systemctl restart nginx

# -------------------------------
# Step 8: Setup Permissions
# -------------------------------
sudo chown -R www-data:www-data $PANEL_DIR
sudo chmod -R 755 $PANEL_DIR/storage $PANEL_DIR/bootstrap/cache

# -------------------------------
# Step 9: Queue Worker Service
# -------------------------------
echo "[*] Creating pteroq.service..."
sudo bash -c "cat > /etc/systemd/system/pteroq.service" <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php ${PANEL_DIR}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now redis-server
sudo systemctl enable --now pteroq.service

# -------------------------------
# Step 10: Cronjob for Scheduler
# -------------------------------
echo "[*] Adding cronjob..."
( sudo crontab -l 2>/dev/null | grep -v 'pterodactyl/artisan schedule:run'; echo "* * * * * php ${PANEL_DIR}/artisan schedule:run >> /dev/null 2>&1" ) | sudo crontab -

# -------------------------------
# Step 11: Create Pterodactyl Admin User (AUTO)
# -------------------------------
echo "[*] Creating Pterodactyl admin user..."
cd ${PANEL_DIR}
php artisan p:user:make

# -------------------------------
# Done
# -------------------------------
echo ""
echo "[✓] Setup completed!"
echo "Panel URL: https://${DOMAIN}"
echo "Database: ${DB_NAME}, User: ${DB_USER}, Pass: ${DB_PASS}"
echo "Panel installed in: ${PANEL_DIR}"
echo ""
echo "Admin user creation complete above. Install is fully automatic!"
