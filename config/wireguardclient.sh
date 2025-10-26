#!/bin/bash
clear
function install_wireguard() {
  echo "1. Installing Wireguard Client..."
  sudo apt install -y wireguard resolvconf

  if [ $? -eq 0 ]; then
    echo "Wireguard installed successfully."
    echo "Creating wg0.conf file..."
    sudo touch /etc/wireguard/wg0.conf
    clear
    echo "Please paste your wg0.conf content and press Ctrl+D:"
    sudo tee /etc/wireguard/wg0.conf > /dev/null
    if [ $? -eq 0 ]; then
      echo "wg0.conf created and configured."
      echo "Starting Wireguard connection..."
      sudo wg-quick up wg0
      if [ $? -eq 0 ]; then
        echo "Wireguard connection established successfully."
        echo "Current Wireguard status:"
        wg
      else
        echo "Failed to start Wireguard connection."
      fi
    else
      echo "Failed to create wg0.conf."
    fi
  else
    echo "Failed to install Wireguard."
  fi
  exit 1
  clear
}

function change_config() {
  echo "2. Editing wg0.conf..."
  sudo nano /etc/wireguard/wg0.conf
  if [ $? -eq 0 ]; then
    echo "wg0.conf edited successfully."
  else
    echo "Failed to edit wg0.conf."
  fi
  exit 1
  clear
}

function toggle_wireguard() {
  echo "3. Toggling Wireguard connection..."
  status=$(sudo wg-quick status wg0 2>/dev/null)
  if [[ -z "$status" ]]; then
    echo "Starting Wireguard connection..."
    sudo wg-quick up wg0
    if [ $? -eq 0 ]; then
      echo "Wireguard connection started successfully."
    else
      echo "Failed to start Wireguard connection."
    fi
  else
    echo "Stopping Wireguard connection..."
    sudo wg-quick down wg0
    if [ $? -eq 0 ]; then
      echo "Wireguard connection stopped successfully."
    else
      echo "Failed to stop Wireguard connection."
    fi
  fi
  exit 1
  clear
}

uninstall_wireguard() {
  clear
  read -p "Do you want to remove Wireguard client? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    sudo apt-get remove --purge -y wireguard resolvconf*
    sudo rm -r /etc/wireguard/
    sudo apt-get autoremove -y
    echo "Unistalled"
  else
    echo "Cancelled"
  fi
  read -n 1 -s -r -p "Press any key to continue..."
  echo ""
}

while true; do
  echo "------------------------------"
  echo "Wireguard Client Menu:"
  echo "------------------------------"
  echo "1. Install Wireguard Client"
  echo "2. Change config Wireguard"
  echo "3. Start/stop Wireguard"
  echo "4. Unistall Wireguard"
  echo "5. Exit"
  read -p "Enter your choice: " choice

  case "$choice" in
  1) install_wireguard ;;
  2) change_config ;;
  3) toggle_wireguard ;;
  4) uninstall_wireguard ;;
  5) exit 0 ;;
  *) echo "Invalid choice. Please try again." ;;
  esac
done
