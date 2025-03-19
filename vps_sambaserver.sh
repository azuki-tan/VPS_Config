                                         #!/bin/bash

# Global variable for user choice
choice=""

# Function to display the SMB menu
show_smb_menu() {
    clear
    echo "-------------------------------"
    echo "Samba Server Menu:"
    echo "-------------------------------"
    echo "1: Install Samba Server"
    echo "2: Create Samba Folder Share"
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
    sudo systemctl unmask smbd
    sudo systemctl start smbd
    echo "Successful!"

}

#Create smb Folder
create_smb_folder(){

    read -p "Enter folder path to share (e.g., /usr): " folder_path
    [[ -z "$folder_path" ]] && { echo "Error: Folder path cannot be empty."; return 1; }

    read -p "Enter Share name (default: folder name): " share_name
    [[ -z "$share_name" ]] && share_name=$(basename "$folder_path")

    read -p "Enter username (leave empty for guest access): " smbusername
    if [[ -z "$smbusername" ]]; then
        guest_access="yes"
        smbpassword=""
    else
        guest_access="no"
        read -sp "Enter password (leave empty for no password): " smbpassword
        [[ -z "$smbpassword" ]] && smbpassword=""
    fi

    # Update Samba configuration
    sudo tee -a /etc/samba/smb.conf <<EOF

[$share_name]
   path = $folder_path
   browsable = no
   writable = yes
   guest ok = $guest_access
   create mask = 0777
   directory mask = 0777
   force user = root
   $( [[ -n "$smbusername" ]] && echo "valid users = $smbusername" )
EOF

    # Create SMB user if necessary
    if [[ -n "$smbusername" ]]; then
        sudo useradd -M "$smbusername" 2>/dev/null || true
        echo -e "$smbpassword\n$smbpassword" | sudo smbpasswd -a "$smbusername" -s
    fi

    # Restart Samba service
    sudo systemctl restart smbd

    # Get LAN and WAN IP addresses
    LAN_IP=$(hostname -I | awk '{print $1}')
    WAN_IP=$(curl -s ifconfig.me)
    
    clear
    echo "\nSMB Share Created Successfully!"
    echo "Access your share at:"
    echo "\\\\$LAN_IP\\$share_name"
    echo "\\\\$WAN_IP\\$share_name"
    if [[ -n "$smbusername" ]]; then
        echo "Username: $smbusername"
        echo "Password:  $smbpassword"
    else
        echo "Guest Access: Enabled"
    fi
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
        sudo useradd -M "$username" || { echo "User creation failed."; return 1; }
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
    pdbedit -L | cut -d: -f1  

    read -r -p "Enter username to change password for: " username
    if ! pdbedit -L | cut -d: -f1 | grep -qw "$username"; then
        echo "Error: Samba user '$username' does not exist."
        return 1
    fi

    read -r -p "Enter new password for $username: " password
    [[ -z "$password" ]] && { echo "Error: Password cannot be empty."; return 1; }
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
        2) create_smb_folder;;
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
