#!/data/data/com.termux/files/usr/bin/bash
# Install Debian proot-distro and configure user

set -euo pipefail

LOG_FILE="${HOME}/termux-debian-auto.log"
DEBIAN_USER="debian"

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

run_in_debian() {
    proot-distro login debian --shared-tmp -- /bin/bash -c "$1" >>"${LOG_FILE}" 2>&1
}

main() {
    print_status info "Installing Debian proot-distro..."
    proot-distro install debian >>"${LOG_FILE}" 2>&1

    print_status info "Updating Debian packages..."
    run_in_debian "apt update && apt upgrade -y"

    print_status info "Installing Debian packages..."
    run_in_debian "apt install -y sudo xfce4 xfce4-terminal xfce4-goodies dbus-x11 firefox-esr"

    print_status info "Creating user: ${DEBIAN_USER}"
    run_in_debian "groupadd -f storage"
    run_in_debian "groupadd -f wheel"
    run_in_debian "useradd -m -g users -G wheel,audio,video,storage -s /bin/bash ${DEBIAN_USER}"

    print_status info "Configuring sudo (NOPASSWD)..."
    run_in_debian "echo '${DEBIAN_USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

    print_status info "Setting timezone..."
    local timezone=$(getprop persist.sys.timezone)
    run_in_debian "rm -f /etc/localtime && cp /usr/share/zoneinfo/${timezone} /etc/localtime"

    print_status info "Setting DISPLAY in user bashrc..."
    run_in_debian "echo 'export DISPLAY=:1' >> /home/${DEBIAN_USER}/.bashrc"

    print_status ok "Debian installed and configured"
}

main "$@"