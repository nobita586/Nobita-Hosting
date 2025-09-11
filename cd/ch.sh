#!/bin/bash

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
RESET="\e[0m"

# Background Colors
BG_RED="\e[41m"
BG_GREEN="\e[42m"
BG_YELLOW="\e[43m"
BG_BLUE="\e[44m"
BG_MAGENTA="\e[45m"
BG_CYAN="\e[46m"
BG_WHITE="\e[47m"

# Styles
BOLD="\e[1m"
DIM="\e[2m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
BLINK="\e[5m"
REVERSE="\e[7m"

# Function to display ASCII art animation
show_ascii_art() {
    clear
    echo -e "${CYAN}${BOLD}"
    # First ASCII art (displayed for 1 second)
    cat << "EOF"
       _ _     _                 
      | (_)   | |                
      | |_ ___| |__  _ __  _   _ 
  _   | | / __| '_ \| '_ \| | | |
 | |__| | \__ \ | | | | | | |_| |
  \____/|_|___/_| |_|_| |_|\__,_|
EOF
    echo -e "${RESET}"
    sleep 1
    
    clear
    echo -e "${GREEN}${BOLD}"
    # Second ASCII art (main banner)
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
    echo -e "${RESET}"
    echo -e "${CYAN}${BOLD}            Your Ultimate Hosting Solution            ${RESET}"
    echo -e ""
}

# Check if curl is installed
check_curl() {
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}${BOLD}Error: curl is not installed.${RESET}"
        echo -e "${YELLOW}Installing curl...${RESET}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &>/dev/null; then
            sudo yum install -y curl
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y curl
        else
            echo -e "${RED}Could not install curl automatically. Please install it manually.${RESET}"
            exit 1
        fi
        echo -e "${GREEN}curl installed successfully!${RESET}"
    fi
}

# Function to display a message box
message_box() {
    local title=$1
    local message=$2
    local width=${3:-50}
    
    echo -e "${BG_BLUE}${WHITE}${BOLD} $(printf "%-${width}s" "$title") ${RESET}"
    echo -e "${BG_WHITE}${BLACK} $(printf "%-${width}s" " ") ${RESET}"
    while IFS= read -r line; do
        echo -e "${BG_WHITE}${BLACK} $(printf "%-${width}s" "$line") ${RESET}"
    done <<< "$(echo "$message" | fold -w $width)"
    echo -e "${BG_WHITE}${BLACK} $(printf "%-${width}s" " ") ${RESET}"
    echo -e "${BG_BLUE}${WHITE}${BOLD} $(printf "%-${width}s" " ") ${RESET}"
}

# Function to display progress bar (fixed without bc)
progress_bar() {
    local duration=${1:-5}
    local width=50
    local increment=0.1
    local steps=$(echo "$duration / $increment" | awk '{print int($1)}')
    local count=0
    
    echo -ne "${GREEN}${BOLD}["
    
    for ((i=0; i<width; i++)); do
        echo -ne " "
    done
    
    echo -ne "]${RESET}"
    echo -ne "\r${GREEN}${BOLD}["
    
    while [ $count -lt $steps ]; do
        sleep $increment
        if [ $((count * width / steps)) -gt $(( (count-1) * width / steps )) ]; then
            echo -ne "▇"
        fi
        count=$((count + 1))
    done
    
    # Fill any remaining space
    for ((i=$(echo "$count * $width / $steps" | awk '{print int($1)}'); i<width; i++)); do
        echo -ne "▇"
    done
    
    echo -ne "]${RESET}"
    echo
}

# Function to run remote scripts with enhanced error handling
run_remote_script() {
    local url=$1
    local script_name=$(basename "$url" .sh)
    
    # Convert script name to proper case
    script_name=$(echo "$script_name" | sed 's/.*/\u&/')
    
    echo -e "${YELLOW}${BOLD}Running: ${CYAN}${script_name}${RESET}"
    echo
    
    check_curl
    
    # Create a temporary file for the script
    local temp_script=$(mktemp)
    
    # Download the script with progress indicator (without showing URL)
    echo -e "${YELLOW}Downloading script...${RESET}"
    if curl --progress-bar --fail "$url" -o "$temp_script" 2>/dev/null; then
        echo -e "${GREEN}✓ Download successful${RESET}"
        
        # Make the script executable
        chmod +x "$temp_script"
        
        echo -e "${YELLOW}Executing script...${RESET}"
        progress_bar 2
        
        # Execute the script
        bash "$temp_script"
        local exit_code=$?
        
        # Clean up
        rm -f "$temp_script"
        
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✓ Script executed successfully${RESET}"
        else
            echo -e "${RED}✗ Script execution failed with exit code: $exit_code${RESET}"
        fi
        
    else
        echo -e "${RED}✗ Failed to download script${RESET}"
        echo -e "${YELLOW}Please check your internet connection${RESET}"
        rm -f "$temp_script"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to run theme script remotely
choose_theme() {
    message_box "THEME SELECTION" "You are about to change the theme of your hosting environment. This will download and execute the theme script."
    run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/th.sh"
}

# Function to view folder contents with enhanced display
view_contents() {
    local current_dir=$(pwd)
    
    echo -e "${BG_BLUE}${WHITE}${BOLD}             FOLDER CONTENTS: $(basename "$current_dir")             ${RESET}"
    echo
    echo -e "${CYAN}${BOLD}Current Directory:${RESET} ${YELLOW}$current_dir${RESET}"
    echo
    echo -e "${GREEN}${BOLD}Files and Directories:${RESET}"
    echo -e "${BG_WHITE}${BLACK}Permissions  Size  Owner   Group   Modified Date  Name${RESET}"
    
    # Use ls with detailed information and human-readable sizes
    ls -lah | awk '
    NR==1 {print}
    NR>1 {
        # Color coding based on file type
        if ($1 ~ /^d/) printf "\033[34m"  # Directories in blue
        else if ($1 ~ /^-.*x/) printf "\033[32m"  # Executables in green
        else if ($1 ~ /^-/) printf "\033[37m"     # Regular files in white
        else if ($1 ~ /^l/) printf "\033[36m"     # Symlinks in cyan
        print $0 "\033[0m"
    }' | more
    
    echo
    read -p "Press Enter to continue..."
}

# Function to show enhanced system information
system_info() {
    echo -e "${BG_BLUE}${WHITE}${BOLD}             SYSTEM INFORMATION             ${RESET}"
    echo
    
    # Get system data
    local hostname=$(hostname)
    local user=$(whoami)
    local directory=$(pwd)
    local system=$(uname -srm)
    local uptime=$(uptime -p 2>/dev/null || uptime)
    local memory=$(free -h 2>/dev/null | awk '/Mem:/ {print $3"/"$2}' || echo "N/A")
    local disk_usage=$(df -h / 2>/dev/null | awk 'NR==2 {print $3"/"$2 " ("$5")"}' || echo "N/A")
    local load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}' || echo "N/A")
    local processes=$(ps aux 2>/dev/null | wc -l || echo "N/A")
    local users=$(who 2>/dev/null | wc -l || echo "N/A")
    
    # Display system data
    echo -e "${CYAN}${BOLD}Hostname:${RESET} ${YELLOW}$hostname${RESET}"
    echo -e "${CYAN}${BOLD}Current User:${RESET} ${YELLOW}$user${RESET}"
    echo -e "${CYAN}${BOLD}Current Directory:${RESET} ${YELLOW}$directory${RESET}"
    echo -e "${CYAN}${BOLD}System:${RESET} ${YELLOW}$system${RESET}"
    echo -e "${CYAN}${BOLD}Uptime:${RESET} ${YELLOW}$uptime${RESET}"
    echo -e "${CYAN}${BOLD}Memory Usage:${RESET} ${YELLOW}$memory${RESET}"
    echo -e "${CYAN}${BOLD}Disk Usage:${RESET} ${YELLOW}$disk_usage${RESET}"
    echo -e "${CYAN}${BOLD}Load Average:${RESET} ${YELLOW}$load_avg${RESET}"
    echo -e "${CYAN}${BOLD}Processes:${RESET} ${YELLOW}$processes${RESET}"
    echo -e "${CYAN}${BOLD}Logged-in Users:${RESET} ${YELLOW}$users${RESET}"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to display main menu with enhanced UI
show_menu() {
    clear
    show_ascii_art
    echo -e "${BG_BLUE}${WHITE}${BOLD}                  MAIN MENU                   ${RESET}"
    echo
    echo -e "${GREEN}${BOLD}  1.${RESET} ${BOLD}Panel${RESET}       - Control panel management"
    echo -e "${GREEN}${BOLD}  2.${RESET} ${BOLD}Wing${RESET}        - Wing server utilities"
    echo -e "${GREEN}${BOLD}  3.${RESET} ${BOLD}Update${RESET}      - Update hosting components"
    echo -e "${GREEN}${BOLD}  4.${RESET} ${BOLD}Uninstall${RESET}   - Remove hosting components"
    echo -e "${GREEN}${BOLD}  5.${RESET} ${BOLD}Blueprint${RESET}   - Server blueprint management"
    echo -e "${GREEN}${BOLD}  6.${RESET} ${BOLD}Cloudflare${RESET}  - Cloudflare utilities"
    echo -e "${GREEN}${BOLD}  7.${RESET} ${BOLD}Change Theme${RESET} - Customize appearance"
    echo -e "${GREEN}${BOLD}  8.${RESET} ${BOLD}View Contents${RESET} - Browse current directory"
    echo -e "${GREEN}${BOLD}  9.${RESET} ${BOLD}System Info${RESET}  - Display system information"
    echo -e "${RED}${BOLD}  10.${RESET} ${BOLD}Exit${RESET}         - Exit the application"
    echo
    echo -e "${BG_BLUE}${WHITE}${BOLD}================================================${RESET}"
    echo -n -e "${CYAN}${BOLD}Enter your choice [1-10]: ${RESET}"
}

# Function to display exit message
exit_message() {
    clear
    echo -e "${GREEN}${BOLD}"
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
    echo -e "${RESET}"
    echo -e "${BG_GREEN}${WHITE}${BOLD}                                                    ${RESET}"
    echo -e "${BG_GREEN}${WHITE}${BOLD}                 THANK YOU FOR USING                 ${RESET}"
    echo -e "${BG_GREEN}${WHITE}${BOLD}                   NOBITA HOSTING                    ${RESET}"
    echo -e "${BG_GREEN}${WHITE}${BOLD}                                                    ${RESET}"
    echo
    echo -e "${YELLOW}${BOLD}For support, please contact:${RESET}"
    echo -e "${CYAN}${BOLD}Discord:${RESET} https://discord.gg/b9HgcRV7TR"
    echo -e "${CYAN}${BOLD}Email:${RESET} support@nobitahosting.host"
    echo
    progress_bar 3
    echo
}

# Main loop
while true; do
    show_menu
    read -r choice

    case $choice in
        1) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/panel.sh" ;;
        2) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/wing.sh" ;;
        3) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/up.sh" ;;
        4) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/uninstalll.sh" ;;
        5) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/blueprint.sh" ;;
        6) run_remote_script "https://raw.githubusercontent.com/nobita586/Nobita-Hosting/main/cd/cloudflare.sh" ;;
        7) choose_theme ;;
        8) view_contents ;;
        9) system_info ;;
        10) 
            exit_message
            exit 0
            ;;
        *) 
            echo -e "${RED}${BOLD}Invalid option! Please enter a number between 1-10.${RESET}"
            read -p "Press Enter to continue..."
            ;;
    esac
done
