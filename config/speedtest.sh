#!/bin/bash

# Default configuration from environment variables
THRESHOLD_DOWNLOAD=${THRESHOLD_DOWNLOAD:-100}
THRESHOLD_UPLOAD=${THRESHOLD_UPLOAD:-50}
IFS=',' read -ra SERVER_IDS <<<"${SERVER_IDS:-63471,44677,9903,26853,1536,3865,22207,50467,13623}"



# Install speedtest CLI
install_speedtest() {
    echo "🔄 Installing speedtest CLI..."

    rm -f speedtest*

    if ! wget -q https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz; then
        echo "❌ Failed to download speedtest CLI"
        exit 1
    fi

    if ! tar xzf ookla-speedtest-1.2.0-linux-x86_64.tgz; then
        echo "❌ Failed to extract speedtest files"
        rm ookla-speedtest-1.2.0-linux-x86_64.tgz
        exit 1
    fi

    rm ookla-speedtest-1.2.0-linux-x86_64.tgz
    chmod +x speedtest

    mkdir -p ~/.config/ookla
    cat >~/.config/ookla/speedtest-cli.json <<EOF
{
  "Settings": {
    "LicenseAccepted": "604ec27f828456331ebf441826292c49276bd3c1bee1a2f65a6452f505c4061c",
    "GDPRAccepted": true
  }
}
EOF

    echo "✅ Speedtest CLI installed successfully"
}

# Check speedtest binary
check_speedtest() {
    if [ ! -f "./speedtest" ]; then
        echo "❌ Speedtest binary not found in current directory"
        echo "🔄 Attempting to install speedtest..."
        install_speedtest
    fi
    chmod +x ./speedtest
}

# Test speed for a single server
test_speed() {
    local server_id=$1
    local result

    echo "🔄 Testing server ID: $server_id..." >&2
    result=$(./speedtest -f json -s "$server_id" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$result" ]; then
        echo "❌ Failed to test server $server_id" >&2
        return 1
    fi

    echo "$result"
    return 0
}

# Analyze JSON result
analyze_result() {
    local json_result=$1
    local has_alert="false"

    # Get values from JSON
    local download_bytes=$(echo "$json_result" | jq -r '.download.bandwidth')
    local upload_bytes=$(echo "$json_result" | jq -r '.upload.bandwidth')
    local ping=$(echo "$json_result" | jq -r '.ping.latency')
    local server_name=$(echo "$json_result" | jq -r '.server.name')
    local server_location=$(echo "$json_result" | jq -r '.server.location')
    local server_country=$(echo "$json_result" | jq -r '.server.country')
    local server_id=$(echo "$json_result" | jq -r '.server.id')

    # Convert bytes/s to Mbps
    local download_mbps=$(echo "scale=2; $download_bytes * 8 / 1000000" | bc)
    local upload_mbps=$(echo "scale=2; $upload_bytes * 8 / 1000000" | bc)

    # Format output
    echo "📍 Server ID: $server_id - $server_name ($server_location, $server_country)"

    # Check download threshold
    if (($(echo "$download_mbps < $THRESHOLD_DOWNLOAD" | bc -l))); then
        echo "⬇️ Download: $download_mbps Mbps ⚠️"
        has_alert="true"
    else
        echo "⬇️ Download: $download_mbps Mbps"
    fi

    # Check upload threshold
    if (($(echo "$upload_mbps < $THRESHOLD_UPLOAD" | bc -l))); then
        echo "⬆️ Upload: $upload_mbps Mbps ⚠️"
        has_alert="true"
    else
        echo "⬆️ Upload: $upload_mbps Mbps"
    fi

    echo "🔄 Ping: $ping ms"
    echo "━━━━━━━━━━━━━━━━━━━━"

    [ "$has_alert" = "true" ] && return 1 || return 0
}

# Main function
main() {
    if [ ${#SERVER_IDS[@]} -eq 0 ]; then
        echo "❌ Error: No server IDs defined"
        exit 1
    fi

    local output=""
    local overall_alert=false
    local test_results=()
    local failed_servers=()

    # Add threshold info at the beginning
    output+="📊 Threshold - Download: $THRESHOLD_DOWNLOAD Mbps, Upload: $THRESHOLD_UPLOAD Mbps"$'\n'
    output+="━━━━━━━━━━━━━━━━━━━━"$'\n\n'

    for server_id in "${SERVER_IDS[@]}"; do
        local result
        if result=$(test_speed "$server_id"); then
            test_results+=("$result")
            output+="$(analyze_result "$result")"$'\n'
            [ $? -eq 1 ] && overall_alert=true
        else
            failed_servers+=("$server_id")
            output+="❌ Failed to test server $server_id"$'\n\n'
        fi
    done

    output+="📊 Summary
Total servers tested: ${#SERVER_IDS[@]}
Successful tests: ${#test_results[@]}"$'\n'

    if [ ${#failed_servers[@]} -gt 0 ]; then
        output+="❌ Failed servers: ${failed_servers[*]}"$'\n'
    fi

    local status="success"
    if $overall_alert; then
        output+="⚠️ Alert: One or more servers below threshold!"$'\n'
        status="alert"
    else
        if [ ${#test_results[@]} -eq 0 ]; then
            output+="❌ Error: All tests failed"$'\n'
            status="error"
        else
            output+="✅ All successful tests are above thresholds"$'\n'
        fi
    fi

    echo -e "$output"

    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        send_telegram_message "$output" "$status"
    fi

    [ "$status" != "success" ] && exit 1 || exit 0
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v bc &>/dev/null; then
        missing_deps+=("bc")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "❌ Error: Missing required dependencies:"
        printf '%s\n' "${missing_deps[@]}"
        echo "Please install them using:"
        echo "sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --install)
        install_speedtest
        exit 0
        ;;
    --help)
        echo "Usage: $0 [--install] [--help]"
        echo "  --install: Force reinstall speedtest CLI"
        echo "  --help: Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  THRESHOLD_DOWNLOAD: Download threshold in Mbps (default: 300)"
        echo "  THRESHOLD_UPLOAD: Upload threshold in Mbps (default: 200)"
        echo "  SERVER_IDS: Comma-separated list of server IDs (default: 44677,22207)"
        echo "  TELEGRAM_BOT_TOKEN: Telegram bot token"
        echo "  TELEGRAM_CHAT_ID: Telegram chat ID"
        echo "  TELEGRAM_THREAD_ID: Telegram thread ID (optional)"
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

# Run checks and main function
# check_dependencies
check_speedtest
main