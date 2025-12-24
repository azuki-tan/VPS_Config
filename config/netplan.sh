RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Lỗi: Script này phải được chạy với quyền sudo.${NC}"
   echo "Vui lòng thử lại với: sudo ./netconfig.sh"
   exit 1
fi

NETPLAN_FILE=$(find /etc/netplan/ -name "*.yaml" | head -n 1)
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
SYSCTL_CUSTOM_CONF="/etc/sysctl.d/99-custom-network.conf"

if [ -z "$NETPLAN_FILE" ]; then
    echo -e "${RED}Không tìm thấy file cấu hình Netplan trong /etc/netplan/.${NC}"
    exit 1
fi

if [ -z "$INTERFACE" ]; then
    read -p "Không tự động phát hiện được card mạng. Vui lòng nhập tên card mạng (ví dụ: ens33): " INTERFACE
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}Tên card mạng không được để trống.${NC}"
        exit 1
    fi
fi

touch "$SYSCTL_CUSTOM_CONF"


backup_config() {
    BACKUP_FILE="${NETPLAN_FILE}.bak_$(date +%F-%T)"
    echo -e "${YELLOW}Đang sao lưu cấu hình hiện tại vào ${BACKUP_FILE}...${NC}"
    cp "$NETPLAN_FILE" "$BACKUP_FILE"
}

set_static_ip() {
    echo "--- Thiết lập địa chỉ IP Tĩnh ---"
    read -p "Nhập địa chỉ IP và subnet (ví dụ: 192.168.1.100/24): " STATIC_IP
    read -p "Nhập địa chỉ Default Gateway (ví dụ: 192.168.1.1): " GATEWAY
    read -p "Nhập các máy chủ DNS (cách nhau bởi dấu phẩy, ví dụ: 8.8.8.8,8.8.4.4): " DNS_SERVERS

    IFS=',' read -r -a DNS_ARRAY <<< "$DNS_SERVERS"
    backup_config
    echo -e "${YELLOW}Đang tạo file cấu hình mới...${NC}"

    cat > "$NETPLAN_FILE" <<EOF
# This is the network config written by netconfig.sh
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$(printf "'%s'," "${DNS_ARRAY[@]}" | sed 's/,$//')]
EOF

    echo -e "${GREEN}Đã ghi cấu hình IP tĩnh thành công vào ${NETPLAN_FILE}.${NC}"
    echo -e "${YELLOW}Chọn 'Áp dụng thay đổi' từ menu để kích hoạt.${NC}"
    read -p "Nhấn Enter để quay lại menu..."
}

set_dhcp() {
    echo "--- Kích hoạt DHCP ---"
    backup_config
    echo -e "${YELLOW}Đang tạo file cấu hình mới...${NC}"

    cat > "$NETPLAN_FILE" <<EOF
# This is the network config written by netconfig.sh
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: true
EOF

    echo -e "${GREEN}Đã ghi cấu hình DHCP thành công vào ${NETPLAN_FILE}.${NC}"
    echo -e "${YELLOW}Chọn 'Áp dụng thay đổi' từ menu để kích hoạt.${NC}"
    read -p "Nhấn Enter để quay lại menu..."
}

set_dns_only() {
    echo "--- Chỉ thay đổi máy chủ DNS ---"
    echo "Chức năng này sẽ giữ nguyên cấu hình IP hiện tại và chỉ cập nhật DNS."
    
    if ! grep -q "dhcp4:" "$NETPLAN_FILE" && ! grep -q "addresses:" "$NETPLAN_FILE"; then
        echo -e "${RED}File cấu hình hiện tại không rõ ràng. Vui lòng đặt lại IP tĩnh hoặc DHCP trước.${NC}"
        read -p "Nhấn Enter để quay lại menu..."
        return
    fi
    
    read -p "Nhập các máy chủ DNS mới (cách nhau bởi dấu phẩy, ví dụ: 1.1.1.1,1.0.0.1): " DNS_SERVERS
    IFS=',' read -r -a DNS_ARRAY <<< "$DNS_SERVERS"
    backup_config
    
    sed -i '/nameservers:/,/addresses:/d' "$NETPLAN_FILE"
    
    cat >> "$NETPLAN_FILE" <<EOF
      nameservers:
        addresses: [$(printf "'%s'," "${DNS_ARRAY[@]}" | sed 's/,$//')]
EOF
    
    echo -e "${GREEN}Đã cập nhật DNS thành công vào ${NETPLAN_FILE}.${NC}"
    echo -e "${YELLOW}Chọn 'Áp dụng thay đổi' từ menu để kích hoạt.${NC}"
    read -p "Nhấn Enter để quay lại menu..."
}

show_current_config() {
    echo "--- Cấu hình Netplan hiện tại (${NETPLAN_FILE}) ---"
    if [ -f "$NETPLAN_FILE" ]; then
        (cat "$NETPLAN_FILE") | while IFS= read -r line; do echo -e "${GREEN}$line${NC}"; done
    else
        echo -e "${RED}Không tìm thấy file cấu hình.${NC}"
    fi
    echo "----------------------------------------------------"
    read -p "Nhấn Enter để quay lại menu..."
}

open_with_nano() {
    echo -e "${YELLOW}Đang mở ${NETPLAN_FILE} bằng nano...${NC}"
    nano "$NETPLAN_FILE"
    echo "Quay lại menu chính."
}

apply_netplan_changes() {
    echo -e "${YELLOW}Sẽ áp dụng cấu hình Netplan. Bạn có thể bị mất kết nối SSH nếu có lỗi.${NC}"
    read -p "Bạn có chắc chắn muốn tiếp tục? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        
        # --- BẮT ĐẦU ĐOẠN MỚI THÊM ---
        echo "Đang dọn dẹp file tạm và sửa quyền hạn..."
        
        # 1. Đặt quyền 600 (chỉ root đọc/ghi) cho toàn bộ file trong /etc/netplan
        # Khắc phục lỗi "permissions are too open"
        if [ -d "/etc/netplan" ]; then
            chmod 600 /etc/netplan/*
        fi

        # 2. Xóa cache cấu hình cũ của Netplan
        # Khắc phục lỗi cache bị kẹt hoặc lỗi quyền trong /run
        rm -rf /run/netplan/*
        # --- KẾT THÚC ĐOẠN MỚI THÊM ---

        echo "Đang áp dụng cấu hình..."
        netplan apply
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Hoàn tất! Hãy kiểm tra lại kết nối mạng của bạn.${NC}"
        else
            echo -e "${RED}Có lỗi xảy ra khi áp dụng Netplan.${NC}"
        fi
    else
        echo "Đã hủy bỏ."
    fi
    read -p "Nhấn Enter để quay lại menu..."
}


update_sysctl_value() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}" "$SYSCTL_CUSTOM_CONF"; then
        sed -i "s/^${key}.*/${key} = ${value}/" "$SYSCTL_CUSTOM_CONF"
    else
        echo "${key} = ${value}" >> "$SYSCTL_CUSTOM_CONF"
    fi
    echo -e "${GREEN}Đã cập nhật: ${key} = ${value}${NC}"
}

manage_kernel_settings() {
    while true; do
        clear
        CURRENT_IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)
        CURRENT_RP_FILTER=$(sysctl -n net.ipv4.conf.all.rp_filter)
        CURRENT_IGNORE_PING=$(sysctl -n net.ipv4.icmp_echo_ignore_all)
        CURRENT_SYN_COOKIES=$(sysctl -n net.ipv4.tcp_syncookies)
        CURRENT_FIN_TIMEOUT=$(sysctl -n net.ipv4.tcp_fin_timeout)
        CURRENT_KEEPALIVE=$(sysctl -n net.ipv4.tcp_keepalive_time)
        CURRENT_IPV6_DISABLED=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
        
        if [[ "$CURRENT_IPV6_DISABLED" -eq 1 ]]; then
            IPV6_STATUS="Tắt"
        else
            IPV6_STATUS="Bật"
        fi

        echo "======================================================"
        echo "            TÙY CHỈNH KERNEL (SYSCTL)"
        echo "======================================================"
        echo -e "File cấu hình: ${YELLOW}${SYSCTL_CUSTOM_CONF}${NC}"
        echo "------------------------------------------------------"
        echo -e "1. Bật/Tắt IPv6                      : ${CYAN}${IPV6_STATUS}${NC} (0=Bật, 1=Tắt)"
        echo -e "2. Chuyển tiếp gói tin (IP Forwarding)  : ${CYAN}${CURRENT_IP_FORWARD}${NC} (0=Tắt, 1=Bật)"
        echo -e "3. Chống giả mạo IP (RP Filter)       : ${CYAN}${CURRENT_RP_FILTER}${NC} (0=Tắt, 1=Nghiêm ngặt, 2=Nới lỏng)"
        echo -e "4. Chặn toàn bộ Ping (ICMP)          : ${CYAN}${CURRENT_IGNORE_PING}${NC} (0=Cho phép, 1=Chặn)"
        echo -e "5. Chống tấn công SYN Flood (SYN Cookies) : ${CYAN}${CURRENT_SYN_COOKIES}${NC} (0=Tắt, 1=Bật)"
        echo -e "6. FIN-WAIT-2 Timeout (giây)           : ${CYAN}${CURRENT_FIN_TIMEOUT}${NC}"
        echo -e "7. Keepalive Time (giây)               : ${CYAN}${CURRENT_KEEPALIVE}${NC}"
        echo "------------------------------------------------------"
        echo "8. Áp dụng tất cả thay đổi Kernel"
        echo "9. Quay lại Menu Chính"
        echo "------------------------------------------------------"
        read -p "Vui lòng chọn một chức năng [1-9]: " sub_choice

        case $sub_choice in
            1)
                read -p "Nhập giá trị mới cho IPv6 (0 để Bật, 1 để Tắt): " val
                update_sysctl_value "net.ipv6.conf.all.disable_ipv6" "$val"
                update_sysctl_value "net.ipv6.conf.default.disable_ipv6" "$val"
                ;;
            2)
                read -p "Nhập giá trị mới cho IP Forwarding (0 hoặc 1): " val
                update_sysctl_value "net.ipv4.ip_forward" "$val"
                ;;
            3)
                read -p "Nhập giá trị mới cho RP Filter (0, 1, hoặc 2): " val
                update_sysctl_value "net.ipv4.conf.all.rp_filter" "$val"
                update_sysctl_value "net.ipv4.conf.default.rp_filter" "$val"
                ;;
            4)
                read -p "Nhập giá trị mới cho Chặn Ping (0 hoặc 1): " val
                update_sysctl_value "net.ipv4.icmp_echo_ignore_all" "$val"
                ;;
            5)
                read -p "Nhập giá trị mới cho SYN Cookies (0 hoặc 1): " val
                update_sysctl_value "net.ipv4.tcp_syncookies" "$val"
                ;;
            6)
                read -p "Nhập giá trị mới cho FIN Timeout (giây): " val
                update_sysctl_value "net.ipv4.tcp_fin_timeout" "$val"
                ;;
            7)
                read -p "Nhập giá trị mới cho Keepalive Time (giây): " val
                update_sysctl_value "net.ipv4.tcp_keepalive_time" "$val"
                ;;
            8)
                echo -e "${YELLOW}Đang áp dụng các thay đổi từ ${SYSCTL_CUSTOM_CONF}...${NC}"
                sysctl -p "$SYSCTL_CUSTOM_CONF"
                echo -e "${GREEN}Hoàn tất!${NC}"
                ;;
            9)
                return ;;
            *)
                echo -e "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1 ;;
        esac
        
        if [[ "$sub_choice" != "9" ]]; then
            echo -e "${YELLOW}Các thay đổi đã được ghi vào file. Chọn 'Áp dụng' để có hiệu lực ngay.${NC}"
            read -p "Nhấn Enter để tiếp tục..."
        fi
    done
}


while true; do
    clear
    echo "======================================================"
    echo "      SCRIPT QUẢN LÝ MẠNG CHO UBUNTU SERVER"
    echo "======================================================"
    echo -e "Card mạng tự động phát hiện: ${YELLOW}${INTERFACE}${NC}"
    echo -e "File cấu hình được quản lý: ${YELLOW}${NETPLAN_FILE}${NC}"
    echo "------------------------------------------------------"
    echo "   --- Cấu hình Netplan ---"
    echo "1. Thiết lập địa chỉ IP Tĩnh"
    echo "2. Kích hoạt DHCP (IP Động)"
    echo "3. Chỉ thay đổi máy chủ DNS"
    echo "4. Xem cấu hình Netplan hiện tại"
    echo "5. Mở file cấu hình Netplan (nano)"
    echo "6. Áp dụng thay đổi Netplan"
    echo "------------------------------------------------------"
    echo "   --- Cấu hình Kernel ---"
    echo "7. Tùy chỉnh Kernel (sysctl)"
    echo "------------------------------------------------------"
    echo "8. Thoát"
    echo "======================================================"
    read -p "Vui lòng chọn một chức năng [1-8]: " choice

    case $choice in
        1) set_static_ip ;;
        2) set_dhcp ;;
        3) set_dns_only ;;
        4) show_current_config ;;
        5) open_with_nano ;;
        6) apply_netplan_changes ;;
        7) manage_kernel_settings ;;
        8) echo "Tạm biệt!"; exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ. Vui lòng thử lại.${NC}"; sleep 2 ;;
    esac
done
