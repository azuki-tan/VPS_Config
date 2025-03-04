#!/bin/bash

# Global variable for user choice
choice=""

# Function to display the SMB menu
show_smb_menu() {
    clear
    echo "Samba Server Menu:"
    echo "1: Install Samba Server"
    echo "2: Edit Samba Configuration"
    echo "3: Create Samba User"
    echo "4: Change Samba User Password"
    echo "5: Start/Stop Samba Server"
    echo "6: Uninstall Samba Server"
    echo "7: Exit"
    read -p "Enter your choice: " choice
}

# Function to install Samba Server
install_smb() {
    echo "Installing Samba Server..."
    sudo apt-get update && sudo apt-get install -y samba

    # Create smb.conf with secure settings
    sudo tee /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = never
   dns proxy = no

[root]
   path = /
   browsable = no
   writable = yes
   guest ok = no
   valid users = root
   create mask = 0777
   directory mask = 0777
   force user = root
EOF

    # Add SMB user (root)
    echo -e "adminserver13\nadminserver13" | sudo smbpasswd -a root -s

    # Restart Samba service
    sudo systemctl restart smbd

    # Get WAN IP address
    WAN_IP=$(curl -s ifconfig.me)

    echo "SMB installed successfully!"
    echo "Access SMB share at: \\\\${WAN_IP}\\root"
    echo "Username: root"
    echo "Password: adminserver13"
}

# Function to edit Samba configuration
edit_smb_config() {
    sudo nano /etc/samba/smb.conf
    sudo systemctl restart smbd
    echo "Samba configuration updated and service restarted."
}

# Function to create a Samba user
create_smb_user() {
    read -r -p "Enter username: " username
    [[ -z "$username" ]] && { echo "Error: Username cannot be empty."; return 1; }

    if ! id "$username" &>/dev/null; then
        read -r -p "User '$username' does not exist. Create it? (y/n): " create_user
        [[ "$create_user" =~ ^[Yy]$ ]] && sudo useradd -M "$username" || { echo "User creation canceled."; return 1; }
    fi

    read -r -s -p "Enter password for $username: " password
    echo
    [[ -z "$password" ]] && { echo "Error: Password cannot be empty."; return 1; }

    echo -e "$password\n$password" | sudo smbpasswd -a "$username" -s
    echo "Samba user '$username' created successfully."
}

# Function to change a Samba user's password
change_smb_user_password() {
    echo "List of Samba users:"
    pdbedit -L | cut -d: -f1  # Hiển thị danh sách user Samba

    read -r -p "Enter username to change password for: " username

    # Check if the Samba user exists
    if ! pdbedit -L | cut -d: -f1 | grep -qw "$username"; then
        echo "Error: Samba user '$username' does not exist."
        return 1
    fi

    read -r -p "Enter new password for $username: " password
    if [ -z "$password" ]; then
       echo "Error: Password cannot be empty."
       return 1
    fi
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
    sudo systemctl stop smbd || true
    sudo apt-get remove -y samba samba-common-bin && sudo apt-get autoremove -y
    sudo rm -rf /etc/samba/
    echo "Samba uninstalled."
}

# Main menu loop
while true; do
    show_smb_menu
    case $choice in
        1) install_smb ;;  
        2) edit_smb_config ;; 
        3) create_smb_user ;; 
        4) change_smb_user_password ;; 
        5) start_stop_smb ;; 
        6) uninstall_smb ;; 
        7) exit 0 ;; 
        *) echo "Invalid choice. Please try again." ;; 
    esac
    read -p "Press Enter to continue..." < /dev/tty
done
