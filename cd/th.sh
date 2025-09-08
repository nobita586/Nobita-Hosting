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

# ------------------------------
# Colors
# ------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------
# Move to target directory
# ------------------------------
DIR="/var/www/pterodactyl"
mkdir -p "$DIR"
cd "$DIR" || { echo -e "${RED}Cannot enter directory${NC}"; exit 1; }

# ------------------------------
# GitHub raw file URL
# ------------------------------
URL="https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/th/nebula.blueprint"

# ------------------------------
# Install aria2 if not installed
# ------------------------------
if ! command -v aria2c >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing aria2...${NC}"
    sudo apt update && sudo apt install aria2 -y
fi

# ------------------------------
# Download the blueprint file
# ------------------------------
echo -e "${YELLOW}Downloading nebula.blueprint from GitHub...${NC}"
aria2c -x 4 -s 4 -o nebula.blueprint "$URL" || { echo -e "${RED}Download failed${NC}"; exit 1; }

echo -e "${GREEN}File downloaded successfully: $DIR/nebula.blueprint${NC}"

# ------------------------------
# Run blueprint if installed
# ------------------------------
if command -v blueprint >/dev/null 2>&1; then
    echo -e "${YELLOW}Running blueprint...${NC}"
    blueprint -i nebula.blueprint
else
    echo -e "${RED}Error: 'blueprint' tool not installed.${NC}"
fi
