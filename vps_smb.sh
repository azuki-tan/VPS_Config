#!/bin/bash

# Function to display the SMB menu
show_smb_menu() {
    clear
    echo "-------------------------------"
    echo "Samba Server Menu:"
    echo "-------------------------------"
    echo "1: Install Samba Server"
    echo "2: New Share Folder"
    echo "3: Edit Samba Configuration"
    echo "4: Create Samba User"
    echo "5: Change Samba User Password"
    echo "6: Start/Stop Samba Server"
    echo "7: Uninstall Samba Server"
    echo "8: Exit"
    read -p "Enter your choice: " choice
}

# Function to install Samba Server
install_smb() {
    echo "Installing Samba Server..."
    sudo apt-get update && sudo apt-get install -y samba
    sudo systemctl enable smbd
    echo "Samba installed successfully!"
}

# Function to create a new shared folder
new_share_folder() {
    read -p "Enter folder path to share (e.g., /usr/share): " folder_path
    read -p "Enter share name (leave empty to use folder name): " share_name
    share_name=${share_name:-$(basename "$folder_path")}

    read -p "Enter username for access (leave empty for guest access): " username
    if [ -z "$username" ]; then
        guest_option="guest ok = yes"
        password="(No password required)"
    else
        guest_option="valid users = $username"
        if id "$username" &>/dev/null; then
            echo "User $username already exists."
        else
            sudo useradd -M "$username"
            echo "User $username created."
        fi
        read -p "Enter password for $username (leave empty for no password): " password
        if [ -n "$password" ]; then
            echo -e "$password\n$password" | sudo smbpasswd -a "$username" -s
        else
            echo "(User $username does not require a password)"
        fi
    fi

    sudo mkdir -p "$folder_path"
    sudo chmod -R 777 "$folder_path"

    echo "
[$share_name]
   path = $folder_path
   browseable = yes
   writable = yes
   create mask = 0777
   directory mask = 0777
   $guest_option
" | sudo tee -a /etc/samba/smb.conf

    sudo systemctl restart smbd
    LAN_IP=$(hostname -I | awk '{print $1}')
    WAN_IP=$(curl -s ifconfig.me)

    echo "Share created successfully!"
    echo "Access it via: \\\\$LAN_IP\\$share_name or \\\\$WAN_IP\\$share_name"
    echo "Username: ${username:-Guest}"
    echo "Password: ${password:-(No password required)}"
}

# Function to edit Samba configuration
edit_smb_config() {
    sudo nano /etc/samba/smb.conf
    sudo systemctl restart smbd
    echo "Samba configuration updated and service restarted."
}

# Function to create a Samba user
create_smb_user() {
    read -p "Enter username: " username
    if id "$username" &>/dev/null; then
        echo "User $username already exists."
    else
        sudo useradd -M "$username"
    fi
    read -s -p "Enter password for $username: " password
    echo -e "$password\n$password" | sudo smbpasswd -a "$username" -s
    echo "Samba user '$username' created successfully."
}

# Function to change a Samba user's password
change_smb_user_password() {
    read -p "Enter username to change password for: " username
    read -s -p "Enter new password for $username: " password
    echo -e "$password\n$password" | sudo smbpasswd -a "$username" -s
    echo "Password for Samba user '$username' changed successfully."
}

# Function to start/stop Samba service
start_stop_smb() {
    if systemctl is-active --quiet smbd; then
        echo "Stopping Samba service..."
        sudo systemctl stop smbd
    else
        echo "Starting Samba service..."
        sudo systemctl start smbd
    fi
}

# Function to uninstall Samba
uninstall_smb() {
    echo "Uninstalling Samba..."
    sudo systemctl stop smbd
    sudo apt-get remove -y samba samba-common-bin && sudo apt-get autoremove -y
    sudo rm -rf /etc/samba/
    echo "Samba uninstalled."
}

# Main menu loop
while true; do
    show_smb_menu
    case $choice in
        1) install_smb ;;
        2) new_share_folder ;;
        3) edit_smb_config ;;
        4) create_smb_user ;;
        5) change_smb_user_password ;;
        6) start_stop_smb ;;
        7) uninstall_smb ;;
        8) exit 0 ;;
        *) echo "Invalid choice. Please try again." ;;
    esac
    read -p "Press Enter to continue..." < /dev/tty
done
