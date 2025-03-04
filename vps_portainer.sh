#!/bin/bash

# Function to display the Portainer menu
show_portainer_menu() {
    clear
    echo "Portainer Menu:"
    echo "1: Install Portainer"
    echo "2: Uninstall Portainer"
    echo "3: Exit"
}

# Function to get the WAN IP address
get_wan_ip() {
    curl -s ifconfig.me
}

# Function to get the LAN IP address
get_lan_ip() {
    ip route get 1.1.1.1 | awk '{print $7}'
}

# Function to install Portainer
install_portainer() {
    echo "Installing Portainer..."
    
    # Create Portainer data volume
    docker volume create portainer_data
    
    # Run Portainer Server
    docker run -d \
        -p 8000:8000 -p 9443:9443 \
        --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:lts
    
    # Get WAN and LAN IP addresses
    WAN_IP=$(get_wan_ip)
    LAN_IP=$(get_lan_ip)
    
    echo "Portainer installed successfully!"
    echo "Access Portainer at:"
    echo "  WAN: https://${WAN_IP}:9443"
    echo "  LAN: https://${LAN_IP}:9443"
}

# Function to uninstall Portainer
uninstall_portainer() {
    echo "Uninstalling Portainer..."
    
    # Stop and remove the Portainer container
    docker stop portainer 2>/dev/null || true  # Ignore errors if container is not running
    docker rm portainer 2>/dev/null || true    # Ignore errors if container does not exist
    
    # Remove the Portainer data volume (optional, removes all stored data)
    docker volume rm portainer_data 2>/dev/null || true
    
    echo "Portainer uninstalled."
}

# Main menu loop
while true; do
    show_portainer_menu
    read -p "Enter your choice: " choice

    case $choice in
        1)
            install_portainer
            read -p "Press Enter to continue..." < /dev/tty
            ;;
        2)
            uninstall_portainer
            read -p "Press Enter to continue..." < /dev/tty
            ;;
        3)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue..." < /dev/tty
            ;;
    esac
done