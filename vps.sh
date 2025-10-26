REPO_URL="https://github.com/azuki-tan/VPS_Config.git"
RAW_URL="https://raw.githubusercontent.com/azuki-tan/VPS_Config/main"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Function to display main menu
show_main_menu() {
    clear
    echo "----------------------------"
    echo "VPS Configuration Menu:"
    echo "----------------------------"
    echo "1:  Docker Compose"
    echo "2:  Portainer"
    echo "3:  WireGuard Server Docker"
    echo "4:  WireGuard Client"
    echo "5:  Samba Server"
    echo "6:  Samba Client"
    echo "7:  Port Forwarding"
    echo "8:  Management Network"
    echo "9:  Speedtest"
    echo "10: Tar_extract"
    echo "11: Exit"
}

# Function: Execute remote script
execute_remote_script() {
    local url="$1"
    echo "🌐 Executing remote script from: $url"
    if ! bash <(curl -fsSL "$url"); then
        echo "❌ Error: Failed to execute $url"
        read -p "Press Enter to continue..." < /dev/tty
        return 1
    fi
    echo "✅ Script executed successfully."
}

# Function: Execute local script
execute_local_script() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "📦 Running local script: $file"
        bash "$file"
        echo "✅ Local script finished."
    else
        echo "⚠️ Local script not found: $file"
    fi
}

# Function: Check for git update and ask user
check_git_update() {
    echo "🔍 Checking for updates from GitHub..."
    git fetch origin main >/dev/null 2>&1
    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse origin/main)
    if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        echo "⬆️ New update available!"
        read -p "Do you want to update now? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            git pull origin main
            echo "✅ Updated successfully. Restarting script..."
            exec bash "$SCRIPT_PATH" "$@"
            exit 0
        else
            echo "⚙️ Skipping update."
        fi
    else
        echo "✅ Already up to date."
    fi
}

# --- Detect mode ---
if [ -d "$SCRIPT_DIR/.git" ] || [ "$(ls "$SCRIPT_DIR" | grep -E '\.sh|\.conf|\.yml' | wc -l)" -gt 3 ]; then
    MODE="offline"
else
    MODE="online"
fi

# --- If offline repo cloned ---
if [ "$MODE" = "offline" ]; then
    echo "📦 Offline mode detected (local files found)"
    cd "$SCRIPT_DIR" || exit 1

    if [ -d "$SCRIPT_DIR/.git" ]; then
        check_git_update
    fi

    while true; do
        show_main_menu
        read -p "Enter your choice: " choice
        case "$choice" in
            1) execute_local_script "./config/dockercompose.sh" ;;
            2) execute_local_script "./config/portainer.sh" ;;
            3) execute_local_script "./config/wireguardserver.sh" ;;
            4) execute_local_script "./config/wireguardclient.sh" ;;
            5) execute_local_script "./config/sambaserver.sh" ;;
            6) execute_local_script "./config/sambaclient.sh" ;;
            7) execute_local_script "./config/socat.sh" ;;
            8) execute_local_script "./config/netplan.sh" ;;
            9) execute_local_script "./config/speedtest.sh" ;;
            10) execute_local_script "./config/tar.sh" ;;
            11) echo "Exiting..."; exit 0 ;;
            *) echo "⚠️ Invalid choice. Try again." ;;
        esac
        read -p "Press Enter to return to menu..." < /dev/tty
    done

# --- If online mode ---
else
    echo "🌐 Online mode detected (no local files found)"
    echo "➡️ Running remote scripts directly from GitHub..."

    while true; do
        show_main_menu
        read -p "Enter your choice: " choice
        case "$choice" in
            1) execute_remote_script "$RAW_URL/config/dockercompose.sh" ;;
            2) execute_remote_script "$RAW_URL/config/portainer.sh" ;;
            3) execute_remote_script "$RAW_URL/config/wireguardserver.sh" ;;
            4) execute_remote_script "$RAW_URL/config/wireguardclient.sh" ;;
            5) execute_remote_script "$RAW_URL/config/sambaserver.sh" ;;
            6) execute_remote_script "$RAW_URL/config/sambaclient.sh" ;;
            7) execute_remote_script "$RAW_URL/config/socat.sh" ;;
            8) execute_remote_script "$RAW_URL/config/netplan.sh" ;;
            9) execute_remote_script "$RAW_URL/config/speedtest.sh" ;;
            10) execute_remote_script "$RAW_URL/config/tar.sh" ;;
            11) echo "Exiting..."; exit 0 ;;
            *) echo "⚠️ Invalid choice. Try again." ;;
        esac
        read -p "Press Enter to return to menu..." < /dev/tty
    done
fi
