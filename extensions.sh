#!/bin/bash
set -e

# ----------------------------
# Configuration
# ----------------------------
DRIVE_FOLDER_URL=""
DOWNLOAD_DIR="/home/ubuntu/extensions_download"
SOURCE_DIR="$DOWNLOAD_DIR/extensions"
PANEL_DIR="/var/www/pterodactyl"

BLUEPRINT_FILES=(
    mcplugins.blueprint
    minecraftplayermanager.blueprint
    monacoeditor.blueprint
    nebula.blueprint
    playerlisting.blueprint
    resourcemanager.blueprint
    versionchanger.blueprint
)

BLUEPRINT_LIST=(
    monacoeditor
    huxregister
    mclogs
    minecraftplayermanager
    minecraftpluginmanager
    resourcealerts
    resourcemanager
    serverbackgrounds
    simplefavicons
    versionchanger
    nebula
    mctools
    mcplugins
)

# ----------------------------
# Step 0: Install gdown if not present
# ----------------------------
if ! command -v gdown &> /dev/null; then
    echo "🔹 Installing gdown..."
    sudo apt update && sudo apt install -y python3-pip
    pip3 install --user gdown
fi

# Fix PATH
export PATH=$PATH:/home/ubuntu/.local/bin

# ----------------------------
# Step 1: Create download directory
# ----------------------------
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# ----------------------------
# Step 2: Download all files from Google Drive folder
# ----------------------------
echo "🔹 Downloading all extensions from Google Drive folder..."
gdown --folder "$DRIVE_FOLDER_URL" || { echo "❌ Failed to download files from Google Drive"; exit 1; }

# ----------------------------
# Step 3: Move only listed blueprint files to /var/www/pterodactyl
# ----------------------------
echo "🔹 Moving selected blueprint files to $PANEL_DIR..."
for f in "${BLUEPRINT_FILES[@]}"; do
    if [ -f "$SOURCE_DIR/$f" ]; then
        sudo mv -f "$SOURCE_DIR/$f" "$PANEL_DIR/" && echo "✅ Moved $f"
    else
        echo "⚠️ File not found: $f"
    fi
done

# ----------------------------
# Step 4: Install blueprint extensions
# ----------------------------
cd "$PANEL_DIR" || { echo "❌ Cannot access $PANEL_DIR"; exit 1; }

echo "🔹 Installing blueprint extensions..."
for ext in "${BLUEPRINT_LIST[@]}"; do
    blueprint -i "$ext" && echo "✅ Installed $ext" || { echo "❌ Failed to install $ext"; exit 1; }
done

echo "🎉 All selected blueprint files moved and installed successfully!"
