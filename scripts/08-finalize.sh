#!/data/data/com.termux/files/usr/bin/bash
# Finalize installation - reload settings, show success message

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
    print_status info "Configuring Termux settings..."

    mkdir -p "${HOME}/.termux"

    if ! grep -q "allow-external-apps" "${HOME}/.termux/termux.properties" 2>/dev/null; then
        echo "allow-external-apps = true" >> "${HOME}/.termux/termux.properties"
    fi

    termux-reload-settings >> "${LOG_FILE}" 2>&1 || true

    print_status info "Cleaning up..."
    rm -f "${HOME}/install.sh" 2>/dev/null || true

    echo
    print_status ok "Installation complete!"
    echo
    echo -e "\033[0;32m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;32m║\033[0m              \033[1;33mtermux-debian-auto is ready!\033[0m              \033[0;32m║\033[0m"
    echo -e "\033[0;32m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo
    echo -e "\033[1;36mCommands:\033[0m"
    echo -e "  \033[1;33mdebian\033[0m      - Enter Debian CLI environment"
    echo -e "  \033[1;33mdebian-gui\033[0m  - Launch XFCE4 desktop via Termux X11"
    echo
    echo -e "\033[1;36mImportant:\033[0m"
    echo -e "  Install Termux-X11 APK from:"
    echo -e "  \033[4;34mhttps://github.com/termux/termux-x11/releases\033[0m"
    echo
    echo -e "  Run \033[1;33msource ~/.bashrc\033[0m or restart Termux to apply changes."
    echo -e "  Then type \033[1;33mdebian-gui\033[0m to launch your desktop!"
}

main "$@"