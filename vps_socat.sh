#!/bin/bash

# Kiểm tra xem socat đã được cài đặt chưa
if ! command -v socat &> /dev/null; then
  echo "socat chưa được cài đặt. Bạn có muốn cài đặt socat? (y/n)"
  read install_socat
  if [[ "$install_socat" == "y" ]]; then
    sudo apt-get update
    sudo apt-get install socat -y
    if [[ $? -ne 0 ]]; then
      echo "Cài đặt socat thất bại."
      exit 1
    fi
    echo "socat đã được cài đặt thành công."
  else
    echo "Yêu cầu socat được cài đặt để tiếp tục."
    exit 1
  fi
fi

# Hàm hiển thị menu và clear màn hình
show_menu() {
  clear
  echo "------------------------------------"
  echo "Menu Port Forwarding Socat"
  echo "------------------------------------"
  echo "1. Start/Stop port forwarding"
  echo "2. Create port forwarding"
  echo "3. Change port forwarding"
  echo "4. Delete port forwarding"
  echo "5. Exit"
  read -p "Chọn tùy chọn: " choice
}

# Hàm hiển thị danh sách port forwarding đang hoạt động
list_forwardings() {
  clear
  echo "Port forwarding working:"
  ps aux | grep "socat TCP-LISTEN" | grep -v grep | awk '{print $2, $11, $12, $13, $14}'
  echo "Port forwarding stopped:"
  ps aux | grep "socat TCP-LISTEN" | grep -v grep | grep "CLOSE_WAIT\|FIN_WAIT1\|FIN_WAIT2" | awk '{print $2, $11, $12, $13, $14}'
}

# Hàm khởi động/dừng port forwarding
start_stop_forwarding() {
  clear
  list_forwardings
  read -p "Enter PID port forwarding: " input
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    sudo kill $input
    echo " $input stopped."
  else
    local listen_port=$(echo $input | awk -F ':' '{print $1}')
    local remote_host=$(echo $input | awk -F ':' '{print $2}')
    local remote_port=$(echo $input | awk -F ':' '{print $3}')
    if [[ -z "$listen_port" || -z "$remote_host" || -z "$remote_port" ]]; then
      echo "Error. Enter listen_port:remote_host:remote_port."
      return
    fi
    socat TCP-LISTEN:$listen_port,fork TCP:$remote_host:$remote_port &
    echo "Port forwarding $listen_port -> $remote_host:$remote_port đã bắt đầu."
  fi
}

# Hàm tạo port forwarding
create_forwarding() {
  clear  
  read -p "Enter listen_port: " listen_port
  read -p "Enter remote_host: " remote_host
  read -p "Enter remote_port: " remote_port
  socat TCP-LISTEN:$listen_port,fork TCP:$remote_host:$remote_port &
  echo "Port forwarding $listen_port -> $remote_host:$remote_port had created."
}

# Hàm thay đổi port forwarding
change_forwarding() {
  clear  
  list_forwardings
  read -p "Enter PID  port forwarding to change: " pid
  read -p "Enter new listen_port: " listen_port
  read -p "Enter new remote_host: " remote_host
  read -p "Enter new remote_port: " remote_port
  sudo kill $pid
  socat TCP-LISTEN:$listen_port,fork TCP:$remote_host:$remote_port &
  echo "$pid changed to $listen_port -> $remote_host:$remote_port."
}

# Hàm xóa port forwarding
delete_forwarding() {
  clear  
  list_forwardings
  read -p "Enter PID port forwarding to delete: " pid
  sudo kill $pid
  echo "Port forwarding with PID $pid deleted."
}

# Vòng lặp chính của menu
while true; do
  show_menu
  case "$choice" in
  1)
    start_stop_forwarding
    ;;
  2)
    create_forwarding
    ;;
  3)
    change_forwarding
    ;;
  4)
    delete_forwarding
    ;;
  5)
    clear
    echo "Thoát."
    exit 0
    ;;
  *)
    echo "Tùy chọn không hợp lệ."
    ;;
  esac
done
