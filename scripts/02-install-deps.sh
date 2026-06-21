#!/data/data/com.termux/files/usr/bin/bash
# Install Termux dependencies (fixed version)

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

main() {
    print_status info "Updating package repositories..."
    log "INFO" "Starting package update"
    retry_command "pkg update -y -o Dpkg::Options::=\"--force-confold\""

    print_status info "Setting up storage access..."
    if [[ ! -d ~/storage ]]; then
        retry_command "termux-setup-storage"
    fi

    print_status info "Upgrading packages..."
    retry_command "pkg upgrade -y -o Dpkg::Options::=\"--force-confold\""

    print_status info "Installing core dependencies..."
    log "INFO" "Starting core dependencies installation"
    
    # Install packages with retry logic
    local packages=(
        proot-distro
        termux-x11-nightly
        pulseaudio
        virglrenderer-android
        dbus
        wget
        git
        firefox-esr
        xfce4
        xfce4-terminal
        xfce4-goodies
        dbus-x11
        pavucontrol-qt
    )
    
    local failed_packages=()
    local installed_count=0
    local total_packages=${#packages[@]}
    
    for package in "${packages[@]}"; do
        print_status info "Installing $package ($((++installed_count))/$total_packages)..."
        if ! retry_command "pkg install -y $package -o Dpkg::Options::=\"--force-confold\""; then
            print_status warn "Failed to install $package"
            log "ERROR" "Failed to install $package"
            failed_packages+=("$package")
        else
            print_status ok "$package installed"
            log "INFO" "Successfully installed $package"
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_status warn "Some packages failed to install: ${failed_packages[*]}"
        log "WARN" "Failed packages: ${failed_packages[*]}"
        print_status warn "You may need to install them manually later"
    fi

    print_status ok "Dependencies installed"
    log "INFO" "All dependencies installed successfully"
}

main "$@"