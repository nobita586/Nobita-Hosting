#!/bin/bash

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

# Function to display ASCII banner
show_banner() {
    echo -e "${CYAN}========================================${RESET}"
    echo -e "${GREEN}          Nobita Hosting${RESET}"
    echo -e "${CYAN}========================================${RESET}"
}

# Check if curl is installed
check_curl() {
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}Error: curl is not installed. Please install it first.${RESET}"
        exit 1
    fi
}

# Function to run remote scripts with error handling
run_remote_script() {
    local url=$1
    echo -e "${YELLOW}Running script from: ${CYAN}$url${RESET}"
    check_curl
    if curl --output /dev/null --silent --head --fail "$url"; then
        bash <(curl -s "$url")
    else
        echo -e "${RED}Failed to fetch script from $url. Please check the URL.${RESET}"
    fi
    read -p "Press Enter to continue..."
}

# Function to run theme script remotely
choose_theme() {
    echo -e "${YELLOW}Running theme script...${RESET}"
    run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/refs/heads/main/cd/th.sh"
}

# Function to view folder contents
view_contents() {
    echo -e "${CYAN}Current folder contents:${RESET}"
    echo "----------------------------------------"
    ls -la
    echo "----------------------------------------"
    read -p "Press Enter to continue..."
}

# Function to show system information
system_info() {
    echo -e "${CYAN}=== System Information ===${RESET}"
    echo "Hostname: $(hostname)"
    echo "Current user: $(whoami)"
    echo "Current directory: $(pwd)"
    echo "System: $(uname -srm)"
    echo "Uptime: $(uptime -p)"
    echo "Memory: $(free -h | awk '/Mem:/ {print $3"/"$2}')"
    read -p "Press Enter to continue..."
}

# Function to display main menu
show_menu() {
    clear
    show_banner
    echo -e "${YELLOW}1.${RESET} Panel"
    echo -e "${YELLOW}2.${RESET} Wing"
    echo -e "${YELLOW}3.${RESET} Update"
    echo -e "${YELLOW}4.${RESET} Uninstall"
    echo -e "${YELLOW}5.${RESET} Blueprint"
    echo -e "${YELLOW}6.${RESET} v4"
    echo -e "${YELLOW}7.${RESET} Change Theme"
    echo -e "${YELLOW}8.${RESET} View Folder Contents"
    echo -e "${YELLOW}9.${RESET} System Information"
    echo -e "${YELLOW}10.${RESET} Exit"
    echo -e "${CYAN}========================================${RESET}"
    echo -n "Enter your choice [1-10]: "
}

# Main loop
while true; do
    show_menu
    read choice

    case $choice in
        1) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/panel.sh" ;;
        2) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/wing.sh" ;;
        3) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/up.sh" ;;
        4) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/uninstalll.sh" ;;
        5) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/blueprint.sh" ;;
        6) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/v4.sh" ;;
        7) choose_theme ;;
        8) view_contents ;;
        9) system_info ;;
        10) 
            echo -e "${GREEN}Goodbye!${RESET}"
            exit 0
            ;;
        *) 
            echo -e "${RED}Invalid option! Please try again.${RESET}"
            read -p "Press Enter to continue..."
            ;;
    esac
done
