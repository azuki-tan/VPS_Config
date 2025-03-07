#!/bin/bash

# Function to display the main menu
show_main_menu() {
    clear
    echo "----------------------------"
    echo "VPS Configuration Menu:"
    echo "----------------------------"
    echo "1: Docker Compose"
    echo "2: Portainer"
    echo "3: WireGuard (wg-easy)"
    echo "4: Samba"
    echo "5: Port Forwarding"
    echo "6: Exit"
}

# Function to execute a remote script using bash <(curl -sSL "URL")
execute_remote_script() {
    local url="$1"
    
    echo "Executing script from $url..."
    if ! bash <(curl -sSL "$url"); then
        echo "❌ Error: Failed to execute script from $url"
        read -p "Press Enter to continue..." < /dev/tty
        return 1
    fi

    echo "✅ Script executed successfully."
}

# Main loop
while true; do
    show_main_menu
    read -p "Enter your choice: " choice

    case "$choice" in
        1) execute_remote_script "https://raw.githubusercontent.com/azuki-tan/VPS_Config/refs/heads/main/vps_dockercompose.sh" ;;
        2) execute_remote_script "https://raw.githubusercontent.com/azuki-tan/VPS_Config/refs/heads/main/vps_portainer.sh" ;;
        3) execute_remote_script "https://raw.githubusercontent.com/azuki-tan/VPS_Config/refs/heads/main/vps_wireguard.sh" ;;
        4) execute_remote_script "https://raw.githubusercontent.com/azuki-tan/VPS_Config/refs/heads/main/vps_smb.sh" ;;
        5) execute_remote_script "https://raw.githubusercontent.com/azuki-tan/VPS_Config/refs/heads/main/vps_socat.sh" ;;
        6) 
            echo "Exiting..."
            exit 0 
            ;;
        *)
            echo "⚠️ Invalid choice. Please try again."
            ;;
    esac

    echo ""  # Thêm dòng trống để UI rõ ràng hơn
    read -p "Press Enter to return to the main menu..." < /dev/tty
done
