#!/bin/bash

SOCAT_CMD=$(command -v socat)
SOCAT_SERVICE_DIR="/etc/systemd/system"
SOCAT_CONFIG_FILE="/var/log/socat_forwarding.log"

# Kiểm tra socat, nếu chưa có thì hỏi có muốn cài không
if [ -z "$SOCAT_CMD" ]; then
    echo -e "\nSocat chưa được cài đặt. Bạn có muốn cài đặt không? (y/n) "
    read -r INSTALL_SOCAT
    if [ "$INSTALL_SOCAT" == "y" ]; then
        sudo apt update && sudo apt install -y socat
    else
        echo "Thoát..." && exit 1
    fi
fi

# Hiển thị danh sách các port forwarding đang chạy
list_forwarding() {
    clear
    echo -e "\n📌 Danh sách port forwarding đang chạy:\n"
    sudo systemctl list-units --type=service | grep socat
    echo -e "\nNhấn Enter để quay lại menu..."
    read -r
}

# Hiển thị danh sách port forwarding trước khi thao tác
list_and_select_service() {
    list_forwarding
    echo -n "Nhập tên service (socat-portX.service) để tiếp tục: "
    read -r SERVICE_NAME
}

# Dừng hoặc khởi động lại một port forwarding
stop_start_forwarding() {
    clear
    list_forwarding
    echo -n "Nhập tên service (socat-portX.service) để dừng hoặc khởi động lại: "
    read -r SERVICE_NAME
    STATUS=$(sudo systemctl is-active "$SERVICE_NAME")
    if [ "$STATUS" == "active" ]; then
        sudo systemctl stop "$SERVICE_NAME"
        echo -e "\n✅ Đã dừng $SERVICE_NAME"
    else
        sudo systemctl start "$SERVICE_NAME"
        echo -e "\n✅ Đã khởi động lại $SERVICE_NAME"
    fi
    sleep 2
}

# Xóa một port forwarding hoàn toàn
delete_forwarding() {
    clear
    list_and_select_service
    if [ -f "$SOCAT_SERVICE_DIR/$SERVICE_NAME" ]; then
        sudo systemctl stop "$SERVICE_NAME"
        sudo systemctl disable "$SERVICE_NAME"
        sudo rm -f "$SOCAT_SERVICE_DIR/$SERVICE_NAME"
        sudo systemctl daemon-reload
        sudo systemctl reset-failed
        echo -e "\n✅ Đã xóa hoàn toàn $SERVICE_NAME"
    else
        echo -e "\n❌ Service không tồn tại hoặc đã bị xóa trước đó."
    fi
    sleep 2
}

# Thay đổi port forwarding
change_forwarding() {
    clear
    delete_forwarding
    create_forwarding
}

# Tạo port forwarding mới
create_forwarding() {
    clear
    echo -n "🔹 Nhập port lắng nghe trên máy local: "
    read -r LOCAL_PORT
    echo -n "🔹 Nhập IP đích: "
    read -r TARGET_IP
    echo -n "🔹 Nhập port đích: "
    read -r TARGET_PORT
    
    SERVICE_NAME="socat-port$LOCAL_PORT.service"
    SERVICE_PATH="$SOCAT_SERVICE_DIR/$SERVICE_NAME"

    echo -e "\n🚀 Tạo port forwarding từ $LOCAL_PORT đến $TARGET_IP:$TARGET_PORT\n"

    echo "[Unit]
Description=Socat Port Forwarding $LOCAL_PORT to $TARGET_IP:$TARGET_PORT
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:$LOCAL_PORT,reuseaddr,fork TCP:$TARGET_IP:$TARGET_PORT
Restart=always
User=root

[Install]
WantedBy=multi-user.target" | sudo tee "$SERVICE_PATH" > /dev/null

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"

    echo -e "\n✅ Port forwarding đã được tạo!\n"
    sleep 2
}

# Hiển thị menu
while true; do
    clear
    echo -e "\n==== MENU SOCAT PORT FORWARDING ===="
    echo "1: Xem danh sách port forwarding"
    echo "2: Dừng/Khởi động lại port forwarding"
    echo "3: Thay đổi port forwarding"
    echo "4: Tạo port forwarding mới"
    echo "5: Xóa port forwarding"
    echo "6: Thoát"
    echo -n "\n🔸 Chọn một tùy chọn: "
    read -r OPTION

    case $OPTION in
        1) list_forwarding ;;
        2) stop_start_forwarding ;;
        3) change_forwarding ;;
        4) create_forwarding ;;
        5) delete_forwarding ;;
        6) echo "Thoát..."; exit 0 ;;
        *) echo "❌ Lựa chọn không hợp lệ!"; sleep 2 ;;
    esac
done
