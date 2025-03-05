#!/bin/bash

# Function to display the WireGuard menu
show_wireguard_menu() {
    clear
    echo "===== WireGuard (wg-easy) Menu ====="
    echo "1: Install WireGuard"
    echo "2: Change WireGuard Password"
    echo "3: Change Mode Connection"
    echo "4: Stop/Start WireGuard Docker"
    echo "5: Exit"
    read -p "Enter your choice: " choice
}

# Function to generate a random password
generate_random_password() {
    local password
    password=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 12)
    echo "$password"
}

# Function to install WireGuard
install_wireguard() {
    echo "Installing WireGuard (wg-easy)..."

    # Get password input (with random default)
    read -r -p "Enter WireGuard web UI password (leave blank for random): " password
    if [ -z "$password" ]; then
        password=$(generate_random_password)
        echo "Generated random password: $password"
    fi

    # Get domain input (with WAN IP default)
    read -r -p "Enter domain name for WireGuard (leave blank for WAN IP): " domain
    if [ -z "$domain" ]; then
        domain=$(curl -s ifconfig.me)
        echo "Using WAN IP: $domain"
    fi

    # Get LAN IP
    lan_ip=$(hostname -I | awk '{print $1}')
    echo "Detected LAN IP: $lan_ip"

    # Create directory for WireGuard configuration
    sudo mkdir -p /etc/docker/wireguard
    cd /etc/docker/wireguard || exit

    # Create docker-compose.yml
    cat <<EOF > docker-compose.yml
version: '3'
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:13
    container_name: wg-easy
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - WG_HOST=$domain
      - WG_DEFAULT_DNS=8.8.8.8,8.8.4.4
      - UI_TRAFFIC_STATS=true
      - UI_CHART_TYPE=2
      - WG_ENABLE_ONE_TIME_LINKS=true
      - PASSWORD=$password
      - WG_PERSISTENT_KEEPALIVE=25
      - WG_ALLOWED_IPS=10.8.0.0/24
    volumes:
      - ./config:/etc/wireguard
EOF

    # Enable IP forwarding
    sudo tee /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
EOF
    sudo sysctl -p

    # Start WireGuard with Docker Compose
    docker compose up -d

    echo "WireGuard (wg-easy) installed successfully!"
    echo "Access the web UI at:"
    echo "  - http://$lan_ip:51821"
    echo "  - http://$domain:51821"
    echo "Password: $password"
}

# Function to change WireGuard password
change_wireguard_password() {
    echo "Changing WireGuard web UI password..."

    read -r -p "Enter new WireGuard web UI password (leave blank for random): " new_password
    if [ -z "$new_password" ]; then
        new_password=$(generate_random_password)
        echo "Generated random password: $new_password"
    fi

    cd /etc/docker/wireguard || { echo "Error: WireGuard directory not found."; exit 1; }
    if ! docker ps -q -f name=wg-easy >/dev/null; then
        echo "Error: WireGuard is not running."
        return
    fi

    sed -i "s|PASSWORD=.*|PASSWORD=$new_password|" docker-compose.yml
    docker compose down
    docker compose up -d

    echo "WireGuard password changed successfully!"
    echo "New Password: $new_password"
}

# Function to change connection mode
change_mode_connection() {
    echo "Select connection mode:"
    echo "1: Only Local LAN"
    echo "2: All Traffic Network"
    read -p "Enter your choice: " mode_choice

    cd /etc/docker/wireguard || { echo "Error: WireGuard directory not found."; exit 1; }

    if [ "$mode_choice" -eq 1 ]; then
        sed -i "s|WG_ALLOWED_IPS=.*|WG_ALLOWED_IPS=10.8.0.0/24|" docker-compose.yml
        echo "Changed to Only Local LAN mode."
    elif [ "$mode_choice" -eq 2 ]; then
        sed -i "s|WG_ALLOWED_IPS=.*|WG_ALLOWED_IPS=0.0.0.0/0, ::/0|" docker-compose.yml
        echo "Changed to All Traffic Network mode."
    else
        echo "Invalid choice."
        return
    fi

    docker compose down
    docker compose up -d
}

# Function to stop/start WireGuard Docker container
stop_start_wireguard() {
    cd /etc/docker/wireguard || { echo "Error: WireGuard directory not found."; exit 1; }

    if docker ps -q -f name=wg-easy >/dev/null; then
        echo "Stopping WireGuard container..."
        docker compose down
    else
        echo "Starting WireGuard container..."
        docker compose up -d
    fi
}

# WireGuard menu loop
while true; do
    show_wireguard_menu

    case $choice in
        1)
            install_wireguard
            read -p "Press Enter to continue..." < /dev/tty
            ;;
        2)
            change_wireguard_password
            read -p "Press Enter to continue..." < /dev/tty
            ;;
        3)
            change_mode_connection
            read -p "Press Enter to continue..." < /dev/tty
            ;;
        4)
            stop_start_wireguard
            read -p "Press Enter to continue..." < /dev/tty
            ;;
        5)
            echo "Exiting WireGuard menu..."
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue..." < /dev/tty
            ;;
    esac
done
