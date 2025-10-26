#!/bin/bash

# Function to display the Portainer menu
show_portainer_menu() {
    clear
    echo "============================"
    echo "    Portainer Management"
    echo "============================"
    echo "1: Install Portainer"
    echo "2: Uninstall Portainer"
    echo "3: Update Portainer"
    echo "4: Exit"
    echo "----------------------------"
}

# Function to get the WAN IP address
get_wan_ip() {
    # Try multiple services for better reliability
    curl -s ifconfig.me || curl -s icanhazip.com
}

# Function to get the LAN IP address
get_lan_ip() {
    # This command is more robust for finding the primary LAN IP
    ip -4 route get 1.1.1.1 | awk '{print $7}' | head -n1
}

# Function to install Portainer
install_portainer() {
    echo "⏳ Installing Portainer..."
    
    # Create Portainer data volume
    echo "  - Creating volume 'portainer_data'..."
    docker volume create portainer_data > /dev/null
    
    # Run Portainer Server
    echo "  - Pulling the latest LTS image..."
    docker pull portainer/portainer-ce:lts > /dev/null

    echo "  - Starting Portainer container..."
    docker run -d \
        -p 8000:8000 -p 9443:9443 \
        --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:lts > /dev/null
    
    # Get WAN and LAN IP addresses
    WAN_IP=$(get_wan_ip)
    LAN_IP=$(get_lan_ip)
    
    echo ""
    echo "✅ Portainer installed successfully!"
    echo "Access Portainer at:"
    [ ! -z "$WAN_IP" ] && echo "   WAN: https://${WAN_IP}:9443"
    [ ! -z "$LAN_IP" ] && echo "   LAN: https://${LAN_IP}:9443"
}

# Function to uninstall Portainer
uninstall_portainer() {
    read -p "⚠️ This will remove the Portainer container. Do you want to also remove all Portainer data (volume)? (y/N): " confirm_delete_data
    echo "⏳ Uninstalling Portainer..."
    
    # Stop and remove the Portainer container
    echo "  - Stopping container 'portainer'..."
    docker stop portainer > /dev/null 2>&1
    echo "  - Removing container 'portainer'..."
    docker rm portainer > /dev/null 2>&1
    
    # Remove the Portainer data volume if confirmed
    if [[ "$confirm_delete_data" == "y" || "$confirm_delete_data" == "Y" ]]; then
        echo "  - Removing volume 'portainer_data'..."
        docker volume rm portainer_data > /dev/null 2>&1
        echo "✅ Portainer and all its data have been removed."
    else
        echo "✅ Portainer container removed. Data volume 'portainer_data' was kept."
    fi
}

# Function to update Portainer
update_portainer() {
    echo "⏳ Updating Portainer..."
    
    # 1. Stop the current container
    echo "  - Stopping the current Portainer container..."
    docker stop portainer
    
    # 2. Remove the current container
    echo "  - Removing the current Portainer container..."
    docker rm portainer
    
    # 3. Pull the latest image to ensure we have the newest version
    echo "  - Pulling the latest 'portainer/portainer-ce:lts' image..."
    docker pull portainer/portainer-ce:lts
    
    # 4. Start a new container with the exact same volume mapping
    echo "  - Starting a new Portainer container with existing data..."
    docker run -d \
        -p 8000:8000 -p 9443:9443 \
        --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:lts > /dev/null
        
    echo "✅ Portainer has been updated successfully!"
}

# Main menu loop
while true; do
    show_portainer_menu
    read -p "Enter your choice: " choice

    case $choice in
        1)
            install_portainer
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        2)
            uninstall_portainer
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        3)
            update_portainer
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
        4)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
    esac
done
