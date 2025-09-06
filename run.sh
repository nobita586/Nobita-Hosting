#!/bin/bash

# CD Menu Script
# This script provides a menu interface for various operations

# Display ASCII Art Banner
show_banner() {
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
    echo ""
}

# Function to display menu
show_menu() {
    clear
    show_banner
    echo "========================================"
    echo "          CD FOLDER MENU"
    echo "========================================"
    echo "1. Panel"
    echo "2. Wing"
    echo "3. Update"
    echo "4. Uninstall"
    echo "5. Blueprint"
    echo "6. v4"
    echo "7. View Folder Contents"
    echo "8. System Information"
    echo "9. Exit"
    echo "========================================"
    echo -n "Enter your choice [1-9]: "
}

# Function to run panel.sh
run_panel() {
    echo "Running Panel script..."
    if [ -f "./panel.sh" ]; then
        chmod +x ./panel.sh
        ./panel.sh
    else
        echo "Error: panel.sh not found in current directory!"
    fi
    read -p "Press Enter to continue..."
}

# Function to run wing.sh
run_wing() {
    echo "Running Wing script..."
    if [ -f "./wing.sh" ]; then
        chmod +x ./wing.sh
        ./wing.sh
    else
        echo "Error: wing.sh not found in current directory!"
    fi
    read -p "Press Enter to continue..."
}

# Function to run update (assuming up.sh is for update)
run_update() {
    echo "Running Update script..."
    if [ -f "./up.sh" ]; then
        chmod +x ./up.sh
        ./up.sh
    else
        echo "Error: up.sh not found in current directory!"
    fi
    read -p "Press Enter to continue..."
}

# Function to run uninstall.sh
run_uninstall() {
    echo "Running Uninstall script..."
    if [ -f "./uninstall.sh" ]; then
        chmod +x ./uninstall.sh
        ./uninstall.sh
    else
        echo "Error: uninstall.sh not found in current directory!"
    fi
    read -p "Press Enter to continue..."
}

# Function to run blueprint.sh
run_blueprint() {
    echo "Running Blueprint script..."
    if [ -f "./blueprint.sh" ]; then
        chmod +x ./blueprint.sh
        ./blueprint.sh
    else
        echo "Error: blueprint.sh not found in current directory!"
    fi
    read -p "Press Enter to continue..."
}

# Function to run v4 (assuming this might be a future script)
run_v4() {
    echo "Running v4 script..."
    if [ -f "./v4.sh" ]; then
        chmod +x ./v4.sh
        ./v4.sh
    else
        echo "v4 script is not available or not found!"
        echo "Please ensure v4.sh file exists."
    fi
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

# Main loop
while true; do
    show_menu
    read choice
    
    case $choice in
        1) run_panel ;;
        2) run_wing ;;
        3) run_update ;;
        4) run_uninstall ;;
        5) run_blueprint ;;
        6) run_v4 ;;
        7) view_contents ;;
        8) system_info ;;
        9) 
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option! Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac
done
