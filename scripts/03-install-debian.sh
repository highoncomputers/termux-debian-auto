#!/data/data/com.termux/files/usr/bin/bash
# Install Debian proot-distro and configure user (fixed version)

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

log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

retry_command() {
    local cmd="$1"
    local max_attempts=3
    local attempt=1
    
    log "INFO" "Executing: $cmd"
    
    while [[ $attempt -le $max_attempts ]]; do
        print_status info "Attempt $attempt/$max_attempts: $cmd"
        if eval "$cmd"; then
            print_status ok "Command succeeded"
            log "INFO" "Command succeeded: $cmd"
            return 0
        else
            print_status warn "Command failed (attempt $attempt)"
            log "WARN" "Command failed (attempt $attempt): $cmd"
            ((attempt++))
            sleep 5
        fi
    done
    
    print_status error "Command failed after $max_attempts attempts"
    log "ERROR" "Command failed after $max_attempts attempts: $cmd"
    return 1
}

run_in_debian() {
    local cmd="$1"
    log "INFO" "Running in Debian: $cmd"
    if ! proot-distro login debian --shared-tmp -- /bin/bash -c "$cmd"; then
        print_status error "Failed to execute in Debian: $cmd"
        log "ERROR" "Failed to execute in Debian: $cmd"
        return 1
    fi
}

validate_debian_installation() {
    local rootfs="${PREFIX}/var/lib/proot-distro/installed-rootfs/debian"
    if [[ ! -d "$rootfs" ]]; then
        print_status error "Debian proot-distro not installed at $rootfs"
        log "ERROR" "Debian proot-distro not found at $rootfs"
        return 1
    fi
    
    if [[ ! -f "$rootfs/etc/os-release" ]]; then
        print_status error "Debian rootfs appears corrupted (missing etc/os-release)"
        log "ERROR" "Debian rootfs corrupted"
        return 1
    fi
    
    print_status ok "Debian proot-distro installation validated"
    return 0
}

main() {
    print_status info "Installing Debian proot-distro..."
    log "INFO" "Starting Debian proot-distro installation"
    
    if ! retry_command "proot-distro install debian"; then
        print_status error "Failed to install Debian proot-distro"
        exit 1
    fi

    print_status info "Validating Debian installation..."
    if ! validate_debian_installation; then
        exit 1
    fi

    print_status info "Updating Debian packages..."
    if ! run_in_debian "apt update && apt upgrade -y"; then
        print_status error "Failed to update Debian packages"
        exit 1
    fi

    print_status info "Installing Debian packages..."
    log "INFO" "Installing essential Debian packages"
    
    # Install only essential packages (XFCE4 already installed in Termux)
    if ! run_in_debian "apt install -y sudo dbus-x11 firefox-esr"; then
        print_status error "Failed to install essential Debian packages"
        exit 1
    fi

    print_status info "Creating user: ${DEBIAN_USER}"
    if ! run_in_debian "groupadd -f storage && groupadd -f wheel && useradd -m -g users -G wheel,audio,video,storage -s /bin/bash ${DEBIAN_USER}"; then
        print_status error "Failed to create user ${DEBIAN_USER}"
        exit 1
    fi

    print_status info "Configuring sudo (NOPASSWD)..."
    log "INFO" "Configuring sudo for user ${DEBIAN_USER}"
    
    # Use visudo for secure sudoers configuration
    local temp_sudoers="${HOME}/temp_sudoers"
    if ! run_in_debian "echo '${DEBIAN_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.new"; then
        print_status error "Failed to create sudoers file"
        exit 1
    fi
    
    if ! run_in_debian "visudo -c -f /etc/sudoers.new && mv /etc/sudoers.new /etc/sudoers"; then
        print_status error "Failed to validate and install sudoers"
        exit 1
    fi

    print_status info "Setting timezone..."
    local timezone=$(getprop persist.sys.timezone)
    if [[ -n "$timezone" ]]; then
        if ! run_in_debian "rm -f /etc/localtime && cp /usr/share/zoneinfo/${timezone} /etc/localtime"; then
            print_status warn "Failed to set timezone (continuing anyway)"
        fi
    else
        print_status warn "No timezone found in system properties"
    fi

    print_status info "Setting DISPLAY in user bashrc..."
    if ! run_in_debian "echo 'export DISPLAY=:1' >> /home/${DEBIAN_USER}/.bashrc"; then
        print_status warn "Failed to set DISPLAY in bashrc (continuing anyway)"
    fi

    print_status ok "Debian installed and configured"
    log "INFO" "Debian installation completed successfully"
}

main "$@"