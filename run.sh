#!/bin/bash

# === Colors ===
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
NC="\033[0m" # reset

# === Animation Function ===
loading() {
    echo -ne "${CYAN}Loading"
    for i in {1..3}; do
        echo -ne "."
        sleep 0.3
    done
    echo -e "${NC}"
    sleep 0.3
}

# === Animated Banner ===
banner() {
    clear
    echo -e "${GREEN}"
    echo "====================================="
    echo "       🚀 Nobita Hosting Menu 🚀     "
    echo "====================================="
    echo -e "${NC}"
}

# === Menu ===
menu() {
    banner
    loading
    echo -e "${YELLOW}Please choose an option:${NC}"
    echo -e " ${CYAN}[1]${WHITE} IPv4 Setup"
    echo -e " ${CYAN}[2]${WHITE} Panel"
    echo -e " ${CYAN}[3]${WHITE} Wings"
    echo -e " ${CYAN}[4]${WHITE} Blueprint"
    echo -e " ${CYAN}[5]${WHITE} Extensions"
    echo -e " ${CYAN}[6]${WHITE} Update"
    echo -e " ${CYAN}[7]${WHITE} Uninstall"
    echo -e " ${CYAN}[8]${WHITE} Exit"
    echo ""
    read -p "Enter your choice [1-8]: " choice
    case $choice in
        1) bash ipv4.sh ;;
        2) bash panel.sh ;;
        3) bash wings.sh ;;
        4) bash Blueprint.sh ;;
        5) bash extensions.sh ;;
        6) bash update.sh ;;
        7) bash uninstall.sh ;;
        8) echo -e "${RED}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1; menu ;;
    esac
}

# === Run Menu ===
menu
