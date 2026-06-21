#!/data/data/com.termux/files/usr/bin/bash
# Configure PulseAudio for audio forwarding

set -euo pipefail

LOG_FILE="${HOME}/termux-debian-auto.log"

print_status() {
    local status=$1
    local message=$2
    case $status in
        ok) echo -e "\033[0;32m[✓]\033[0m $message" ;;
        warn) echo -e "\033[1;33m[!]\033[0m $message" ;;
        error) echo -e "\033[0;31m[✗]\033[0m $message" ;;
        info) echo -e "\033[0;34m[i]\033[0m $message" ;;
    esac
}

main() {
    print_status info "Configuring PulseAudio..."

    cat > "${HOME}/.sound" << 'EOF'
pulseaudio --start --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
EOF

    if ! grep -q "source .sound" "${HOME}/.bashrc" 2>/dev/null; then
        echo "source .sound" >> "${HOME}/.bashrc"
    fi

    if ! grep -q "PULSE_SERVER" "${HOME}/.bashrc" 2>/dev/null; then
        echo "export PULSE_SERVER=127.0.0.1" >> "${HOME}/.bashrc"
    fi

    print_status ok "PulseAudio configured"
}

main "$@"