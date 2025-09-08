#!/bin/bash

# Function to display ASCII banner
show_banner() {
    echo "========================================"
    echo "          CD FOLDER MENU"
    echo "========================================"
}

# Function to run remote scripts
run_remote_script() {
    local url=$1
    echo "Running script from $url ..."
    bash <(curl -s "$url")
    read -p "Press Enter to continue..."
}

# Function to run theme script remotely
choose_theme() {
    echo "Running theme script..."
    bash <(curl -s https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/th.sh)
    read -p "Press Enter to continue..."
}

# Function to view folder contents
view_contents() {
    echo "Current folder contents:"
    echo "----------------------------------------"
    ls -la
    echo "----------------------------------------"
    read -p "Press Enter to continue..."
}

# Function to show system information
system_info() {
    echo "=== System Information ==="
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
    echo "1. Panel"
    echo "2. Wing"
    echo "3. Update"
    echo "4. Uninstall"
    echo "5. Blueprint"
    echo "6. v4"
    echo "7. Change Theme"
    echo "8. View Folder Contents"
    echo "9. System Information"
    echo "10. Exit"
    echo "========================================"
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
        4) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/refs/heads/main/cd/uninstalll.sh" ;;
        5) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/blueprint.sh" ;;
        6) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/v4.sh" ;;
        7) choose_theme ;;
        8) view_contents ;;
        9) system_info ;;
        10) 
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option! Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac
done
