#!/bin/bash

# Kiểm tra và cài đặt các gói cần thiết
clear
check_packages() {
  if ! dpkg -s smbclient &> /dev/null; then
    read -p "smbclient is not install. Install? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
      sudo apt-get update
      sudo apt-get install -y smbclient
    else
      echo "Cancelled!"
      exit 1
    fi
  fi

  if ! dpkg -s cifs-utils &> /dev/null; then
    read -p "cifs-utils is not install. Install? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
      sudo apt-get install -y cifs-utils
    else
      echo "Cancelled!"
      exit 1
    fi
  fi

  if ! dpkg -s linux-modules-extra-$(uname -r) &> /dev/null; then
      read -p "linux-modules-extra-$(uname -r) is not install. Install? (y/n): " confirm
      if [[ "$confirm" == "y" ]]; then
          sudo apt-get install -y linux-modules-extra-$(uname -r)
      else
          echo "Cancelled"
          exit 1
      fi
  fi
}

# Load module nls_utf8
load_utf8_module() {
  sudo modprobe nls_utf8
}

# Kết nối đến máy chủ Samba
connect_samba_server() {
  clear
  read -p "Enter IP Samba Server (example: //192.168.1.100/share): " server_address
  read -p "Enter mount point (example: /mnt/smb): " mount_point
  read -p "Username: " username
  read -sp "Password: " password
  echo ""  # Thêm dòng mới để tránh hiển thị mật khẩu
  sudo mkdir -p "$mount_point"
  sudo mount -t cifs "$server_address" "$mount_point" -o username="$username",password="$password"
  if [ $? -eq 0 ]; then
    read -n 1 -s -r -p "Successful! Press any key to continue..."
    echo ""
  else
    echo "Error connecting. Try with SMB v2..."
    sudo mount -t cifs "$server_address" "$mount_point" -o username="$username",password="$password",vers=2.0
    if [ $? -eq 0 ]; then
      read -n 1 -s -r -p "Successful (SMB v2)! Press any key to continue..."
      echo ""
    else
      echo "Error connect."
      echo "Error dmesg:"
      sudo dmesg | tail -20
      read -n 1 -s -r -p "Press any key to continue..."
      echo ""
    fi
  fi
}

# Liệt kê các kết nối Samba đang hoạt động
list_connected_samba_servers() {
  clear
  findmnt -t cifs
  read -n 1 -s -r -p "Press any key to continue...."
  echo ""
}

# Gỡ folder mount
umount_samba_server() {
  clear
  list_connected_samba_servers
  read -p "Enter Target to remove: " mount_point
  sudo umount "$mount_point"
  if [ $? -eq 0 ]; then
    echo "Remove Successful!"
  else
    echo "Error Target"
  fi
  read -n 1 -s -r -p "Press any key to continue..."
  echo ""
}

# Gỡ bỏ cài đặt Samba
uninstall_samba() {
  clear
  read -p "Do you want to remove samba client? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    sudo apt-get remove --purge -y smbclient cifs-utils samba*
    sudo apt-get autoremove -y
    echo "Unistalled"
  else
    echo "Cancelled"
  fi
  read -n 1 -s -r -p "Press any key to continue..."
  echo ""
}

# Hiển thị menu chính
display_menu() {
  clear
  echo "--------------------------"
  echo "Menu Samba Client"
  echo "--------------------------"
  echo "1: Create mount connect to Samba"
  echo "2: List connected Samba"
  echo "3: Unistall Samba"
  echo "4: Remove mount mount"
  echo "5: Exit"
  read -p "Choose number: " choice
  case "$choice" in
    1) connect_samba_server ;;
    2) list_connected_samba_servers ;;
    3) uninstall_samba ;;
    4) umount_samba_server ;;
    5) exit 0;;
    *) echo "Error" ;;
  esac
}

# Thực thi các bước cài đặt và tải module
check_packages
load_utf8_module

# Vòng lặp hiển thị menu
while true; do
  display_menu
done
