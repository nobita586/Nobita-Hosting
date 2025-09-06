#!/bin/bash

# ------------------------
# Benar ASCII Art Banner
# ------------------------
cat << "EOF"
888b      88               88           88                       
8888b     88               88           ""    ,d               
88 `8b    88               88                 88                
88  `8b   88   ,adPPYba,   88,dPPYba,   88  MM88MMM  ,adPPYYba,  
88   `8b  88  a8"     "8a  88P'    "8a  88    88     ""     `Y8  
88    `8b 88  8b       d8  88       d8  88    88     ,adPPPPP88  
88     `8888  "8a,   ,a8"  88b,   ,a8"  88    88,    88,    ,88  
88      `888   `"YbbdP"'   8Y"Ybbd8"'   88    "Y888  `"8bbdP"Y8  
EOF

# ------------------------
# 1. Docker install (stable)
# ------------------------
echo "[*] Installing Docker..."
curl -sSL https://get.docker.com/ | CHANNEL=stable bash

# Enable and start Docker service
echo "[*] Enabling and starting Docker..."
sudo systemctl enable --now docker

# ------------------------
# 2. Update GRUB_CMDLINE_LINUX_DEFAULT
# ------------------------
GRUB_FILE="/etc/default/grub"

if [ -f "$GRUB_FILE" ]; then
    echo "[*] Updating GRUB_CMDLINE_LINUX_DEFAULT..."
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' $GRUB_FILE
    echo "[*] Updating GRUB..."
    sudo update-grub
else
    echo "[!] GRUB config file not found at $GRUB_FILE"
fi

# ------------------------
# 3. Pterodactyl Wings install
# ------------------------
echo "[*] Installing Pterodactyl Wings..."
sudo mkdir -p /etc/pterodactyl

ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    ARCH="amd64"
else
    ARCH="arm64"
fi

curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH"
sudo chmod u+x /usr/local/bin/wings

echo "[*] Wings installed at /usr/local/bin/wings"

# ------------------------
# 4. Create wings.service
# ------------------------
echo "[*] Creating systemd service for Wings..."
WINGS_SERVICE_FILE="/etc/systemd/system/wings.service"

sudo tee $WINGS_SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wings
echo "[*] Wings service created (manual start required)"

# ------------------------
# 5. Create SSL certificate
# ------------------------
echo "[*] Generating SSL certificate for Wings..."
sudo mkdir -p /etc/certs/wing
cd /etc/certs/wing || exit

sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

echo "[*] SSL certificate generated at /etc/certs/wing"

# ------------------------
# 6. Add 'wing' command helper
# ------------------------
echo "[*] Adding 'wing' command helper..."
WING_CMD_FILE="/usr/local/bin/wing"

sudo tee $WING_CMD_FILE > /dev/null <<'EOF'
#!/bin/bash
echo "[!] To start Wings, run manually:"
echo "    sudo systemctl start wings"
echo "[!] Make sure Node port 8080 → 443 is mapped."
EOF

sudo chmod +x $WING_CMD_FILE
echo "[*] 'wing' command helper added."

# ------------------------
# 7. User guidance
# ------------------------
echo "[!] Setup complete!"
echo "[!] Do NOT run Wings automatically."
echo "[!] To start Wings manually, run:"
echo "    sudo systemctl start wings"
echo "[!] Note: Only after mapping Node port 8080 → 443 will the 'wing on' command work."
