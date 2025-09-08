#!/bin/bash

# ------------------------------
# Benar ASCII Art Banner
# ------------------------------
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------
# Nobita hosting
# ------------------------------

DIR="/var/www/pterodactyl"
mkdir -p "$DIR" || { echo -e "${RED}Directory cannot be created${NC}"; exit 1; }
cd "$DIR" || { echo -e "${RED}Cannot enter directory${NC}"; exit 1; }

URL="https://www.mediafire.com/file/o3wlsu0kn6us5da/nebula.blueprint/file"

echo -e "${YELLOW}Fetching MediaFire download link...${NC}"
REAL_URL=$(curl -s "$URL" | grep -oP 'kNO=\\"(.*?)\\"' | head -1 | cut -d'"' -f2)

if [ -z "$REAL_URL" ]; then
    echo -e "${RED}Download link not found. MediaFire page format may have changed.${NC}"
    exit 1
fi

echo -e "${GREEN}Download link found! Starting download...${NC}"
wget --progress=bar:force -O nebula.blueprint "$REAL_URL" || { echo -e "${RED}Download failed${NC}"; exit 1; }

echo -e "${GREEN}File downloaded successfully: $DIR/nebula.blueprint${NC}"

if command -v blueprint >/dev/null 2>&1; then
    echo -e "${YELLOW}Running blueprint...${NC}"
    blueprint -i nebula.blueprint
else
    echo -e "${RED}Error: 'blueprint' tool not installed.${NC}"
    exit 1
fi
