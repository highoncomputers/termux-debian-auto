#!/data/data/com.termux/files/usr/bin/bash
# Configure hardware acceleration (VirGL/virpipe)

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
    print_status info "Configuring hardware acceleration..."

    if ! grep -q "GALLIUM_DRIVER" "${HOME}/.bashrc" 2>/dev/null; then
        echo "export GALLIUM_DRIVER=virpipe" >> "${HOME}/.bashrc"
        echo "export MESA_GL_VERSION_OVERRIDE=4.0" >> "${HOME}/.bashrc"
    fi

    print_status ok "Hardware acceleration configured (virpipe)"
}

main "$@"