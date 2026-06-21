#!/data/data/com.termux/files/usr/bin/bash
# Install Termux dependencies

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
    print_status info "Updating package repositories..."
    pkg update -y -o Dpkg::Options::="--force-confold" >>"${LOG_FILE}" 2>&1

    print_status info "Changing to fastest mirror..."
    termux-change-repo >>"${LOG_FILE}" 2>&1 || true

    print_status info "Setting up storage access..."
    if [[ ! -d ~/storage ]]; then
        termux-setup-storage >>"${LOG_FILE}" 2>&1 || true
    fi

    print_status info "Upgrading packages..."
    pkg upgrade -y -o Dpkg::Options::="--force-confold" >>"${LOG_FILE}" 2>&1

    print_status info "Installing core dependencies..."
    pkg install -y \
        proot-distro \
        termux-x11-nightly \
        pulseaudio \
        virglrenderer-android \
        x11-repo \
        tur-repo \
        dbus \
        wget \
        git \
        firefox \
        xfce4 \
        xfce4-terminal \
        xfce4-goodies \
        dbus-x11 \
        pavucontrol-qt \
        -o Dpkg::Options::="--force-confold" >>"${LOG_FILE}" 2>&1

    print_status ok "Dependencies installed"
}

main "$@"