#!/bin/bash
# Playit.gg IPv4 Tunnel Setup (24/7 Autostart + Auto Show Tunnel Link)

set -e

PLAYIT_URL="https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64"
PLAYIT_BIN="/usr/local/bin/playit"

echo ">>> Downloading Playit Agent..."
wget -O playit-linux-amd64 "$PLAYIT_URL"

echo ">>> Moving to /usr/local/bin/playit..."
sudo mv playit-linux-amd64 "$PLAYIT_BIN"

echo ">>> Making it executable..."
chmod +x "$PLAYIT_BIN"

# Create systemd service
echo ">>> Creating systemd service..."
cat >/etc/systemd/system/playit.service <<EOF
[Unit]
Description=Playit.gg Agent (IPv4 Tunnel 24/7)
After=network.target

[Service]
ExecStart=$PLAYIT_BIN
Restart=always
RestartSec=5
User=root
WorkingDirectory=/root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo ">>> Step 1: Reloading systemd..."
systemctl daemon-reload

echo ">>> Step 2: Enabling Playit service (autostart)..."
systemctl enable playit

echo ">>> Step 3: Starting Playit service now..."
systemctl restart playit

sleep 5
echo ">>> Checking tunnel link from logs..."
TUNNEL_LINK=$(journalctl -u playit -n 50 --no-pager | grep -Eo "tcp://[a-zA-Z0-9.-]+:[0-9]+|udp://[a-zA-Z0-9.-]+:[0-9]+" | tail -n 1)

if [[ -n "$TUNNEL_LINK" ]]; then
    echo "✅ Tunnel Active: $TUNNEL_LINK"
else
    echo "⚠️ Tunnel link not found yet. Use this command to watch logs:"
    echo "   journalctl -u playit -f"
fi
