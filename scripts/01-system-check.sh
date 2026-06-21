#!/data/data/com.termux/files/usr/bin/bash
# System compatibility check

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
    print_status info "Checking system compatibility..."

    # Check Android
    if [[ "$(uname -o)" != "Android" ]]; then
        print_status error "Not running on Android"
        exit 1
    fi
    print_status ok "Running on Android $(getprop ro.build.version.release)"

    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        print_status warn "Architecture: $arch (aarch64 recommended)"
    else
        print_status ok "Architecture: $arch"
    fi

    # Check Termux
    if [[ -z "${PREFIX:-}" ]]; then
        print_status error "Termux PREFIX not set"
        exit 1
    fi
    print_status ok "Termux PREFIX: ${PREFIX}"

    # Check storage
    local free_space=$(df "${HOME}" | awk 'NR==2 {print $4}')
    if [[ $free_space -lt 4194304 ]]; then
        print_status warn "Low storage: $(df -h "${HOME}" | awk 'NR==2 {print $4}') free (4GB recommended)"
    else
        print_status ok "Storage: $(df -h "${HOME}" | awk 'NR==2 {print $4}') free"
    fi

    # Check RAM
    local total_ram=$(free -m | awk 'NR==2 {print $2}')
    if [[ $total_ram -lt 2048 ]]; then
        print_status warn "Low RAM: ${total_ram}MB (2GB+ recommended)"
    else
        print_status ok "RAM: ${total_ram}MB"
    fi

    print_status ok "System checks passed"
}

main "$@"