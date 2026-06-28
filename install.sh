#!/data/data/com.termux/files/usr/bin/bash
# termux-debian-auto - One-shot Debian Trixie + XFCE4 for Termux
# Repository: https://github.com/highoncomputers/termux-debian-auto
# License: GPL-3.0
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash

set -euo pipefail

# ========== Config ==========
DEBIAN_USER="debian"
LOG_FILE="${HOME}/termux-debian-auto.log"
STATE_DIR="${HOME}/.termux-debian-auto"
ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_HOME="${ROOTFS}/home/${DEBIAN_USER}"

exec 2>>"${LOG_FILE}"

# ========== Colors ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        ok) echo -e "${GREEN}[✓]${NC} $message" ;;
        warn) echo -e "${YELLOW}[!]${NC} $message" ;;
        error) echo -e "${RED}[✗]${NC} $message" ;;
        info) echo -e "${BLUE}[i]${NC} $message" ;;
    esac
}

log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

retry() {
    local cmd="$1"
    local max_attempts=3
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$cmd"; then
            return 0
        fi
        print_status warn "Retrying (${attempt}/${max_attempts})..."
        log "WARN" "Retry ${attempt}/${max_attempts}: $cmd"
        ((attempt++))
        sleep 3
    done
    print_status error "Failed after ${max_attempts} attempts: $cmd"
    log "ERROR" "Failed after ${max_attempts} attempts: $cmd"
    return 1
}

step_header() {
    local current=$1
    local total=$2
    local name=$3
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE} Step ${current}/${total}: ${name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

is_step_done() {
    [[ -f "${STATE_DIR}/$1" ]]
}

mark_step_done() {
    mkdir -p "${STATE_DIR}"
    touch "${STATE_DIR}/$1"
}

# ========== Step 1: System Check ==========
step_system_check() {
    step_header 1 9 "System Check"
    print_status info "Checking system compatibility..."

    if [[ ! -d /data/data/com.termux ]]; then
        print_status error "This script must be run inside Termux on Android"
        exit 1
    fi

    local arch
    arch=$(uname -m)
    print_status ok "Architecture: ${arch}"

    local storage_avail
    storage_avail=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $storage_avail -lt 4000000 ]]; then
        print_status error "Insufficient storage (need 4GB+, have $((storage_avail/1024))MB)"
        exit 1
    fi
    print_status ok "Storage: $((storage_avail/1024))MB available"

    print_status ok "System check passed"
    log "INFO" "System check passed"
}

# ========== Step 2: Install Termux Dependencies ==========
step_install_deps() {
    step_header 2 9 "Installing Termux Packages"

    if is_step_done "deps"; then
        print_status info "Already completed, skipping"
        return
    fi

    print_status info "Updating package repositories..."
    retry "pkg update -y -o Dpkg::Options::=\"--force-confold\" 2>&1 | tail -3"

    print_status info "Upgrading packages..."
    retry "pkg upgrade -y -o Dpkg::Options::=\"--force-confold\" 2>&1 | tail -3"

    print_status info "Setting up storage access..."
    termux-setup-storage 2>/dev/null || print_status warn "Storage setup skipped (non-fatal)"

    local packages=(
        proot-distro
        x11-repo
        termux-x11-nightly
        pulseaudio
        wget
    )

    local count=0
    local total=${#packages[@]}
    local failed=()

    for pkg in "${packages[@]}"; do
        ((count++))
        print_status info "[${count}/${total}] Installing ${pkg}..."
        if ! retry "pkg install -y ${pkg} -o Dpkg::Options::=\"--force-confold\" 2>&1 | tail -2"; then
            print_status warn "Failed to install ${pkg}"
            log "WARN" "Failed to install ${pkg}"
            failed+=("$pkg")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        print_status warn "Some packages failed: ${failed[*]}"
    fi

    mark_step_done "deps"
    print_status ok "Termux packages installed"
    log "INFO" "Termux packages installed"
}

# ========== Step 3: Install Debian Trixie ==========
step_install_trixie() {
    step_header 3 9 "Installing Debian Trixie (via Docker image)"

    if is_step_done "trixie"; then
        print_status info "Already installed, skipping"
        return
    fi

    if [[ -d "$ROOTFS" ]]; then
        print_status warn "Debian rootfs already exists — removing"
        proot-distro remove debian 2>/dev/null || true
        rm -rf "$ROOTFS" 2>/dev/null || true
    fi

    print_status info "Pulling debian:trixie from Docker Hub..."
    if ! retry "proot-distro install debian:trixie 2>&1 | tail -5"; then
        print_status error "Failed to install Debian Trixie"
        print_status info "Check internet connection and try again"
        exit 1
    fi

    if [[ ! -d "$ROOTFS" ]]; then
        print_status error "Debian rootfs not found at ${ROOTFS}"
        print_status info "Container name from 'debian:trixie' image may differ"
        local found
        found=$(proot-distro list 2>/dev/null | grep -i debian | head -1 | awk '{print $1}')
        if [[ -n "$found" ]]; then
            print_status info "Found container: ${found}"
            print_status info "Please rename it: proot-distro rename ${found} debian"
        fi
        exit 1
    fi

    mark_step_done "trixie"
    print_status ok "Debian Trixie installed"
    log "INFO" "Debian Trixie installed"
}

# ========== Step 4: Configure Debian ==========
step_configure_debian() {
    step_header 4 9 "Configuring Debian Trixie"

    if is_step_done "configured"; then
        print_status info "Already configured, skipping"
        return
    fi

    print_status info "Updating package lists..."
    retry "proot-distro login debian -- bash -c 'apt-get update -y 2>&1 | tail -3'"

    print_status info "Upgrading packages..."
    proot-distro login debian -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tail -3' || true

    print_status info "Installing Debian packages (sudo, xfce4, firefox, etc.)..."
    proot-distro login debian -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y sudo curl wget git nano xfce4 dbus-x11 firefox-esr pavucontrol-qt 2>&1 | tail -5' || print_status warn "Some packages may not have installed"

    print_status info "Creating user '${DEBIAN_USER}'..."
    proot-distro login debian -- bash -c "groupadd -f storage 2>/dev/null; groupadd -f wheel 2>/dev/null; useradd -m -g users -G wheel,audio,video,storage -s /bin/bash ${DEBIAN_USER} 2>/dev/null || echo 'User exists'"

    print_status info "Configuring sudo (NOPASSWD)..."
    proot-distro login debian -- bash -c "echo '${DEBIAN_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${DEBIAN_USER} && chmod 440 /etc/sudoers.d/${DEBIAN_USER}"

    print_status info "Setting environment variables..."
    proot-distro login debian -- bash -c "echo 'export DISPLAY=:0' >> /home/${DEBIAN_USER}/.bashrc"
    proot-distro login debian -- bash -c "echo 'export PULSE_SERVER=127.0.0.1' >> /home/${DEBIAN_USER}/.bashrc"

    mark_step_done "configured"
    print_status ok "Debian Trixie configured"
    log "INFO" "Debian Trixie configured"
}

# ========== Step 5: Configure XFCE4 ==========
step_configure_xfce4() {
    step_header 5 9 "Configuring XFCE4 Desktop"

    if is_step_done "xfce4"; then
        print_status info "Already configured, skipping"
        return
    fi

    if [[ ! -d "${DEBIAN_HOME}" ]]; then
        print_status error "Debian home directory not found: ${DEBIAN_HOME}"
        exit 1
    fi

    mkdir -p "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml" \
             "${DEBIAN_HOME}/.config/xfce4/terminal" \
             "${DEBIAN_HOME}/.config/gtk-3.0"

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'EOF'
<?xml version="1.1" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/xfce/xfce-teal.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'EOF'
<?xml version="1.1" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
  </property>
</channel>
EOF

    cat > "${DEBIAN_HOME}/.config/xfce4/terminal/terminalrc" << 'EOF'
[Configuration]
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=80x24
MiscMenubarDefault=TRUE
MiscConfirmClose=TRUE
MiscTabCloseButtons=TRUE
MiscHighlightUrls=TRUE
MiscCopyOnSelect=FALSE
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.850000
TitleMode=TERMINAL_TITLE_HIDE
ScrollingUnlimited=TRUE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
FontName=Monospace 12
EOF

    cat > "${DEBIAN_HOME}/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
EOF

    proot-distro login debian -- bash -c "chown -R ${DEBIAN_USER}:${DEBIAN_USER} /home/${DEBIAN_USER}/.config 2>/dev/null || true"

    mark_step_done "xfce4"
    print_status ok "XFCE4 configured"
    log "INFO" "XFCE4 configured"
}

# ========== Step 6: Configure PulseAudio ==========
step_configure_audio() {
    step_header 6 9 "Configuring PulseAudio"

    if is_step_done "audio"; then
        print_status info "Already configured, skipping"
        return
    fi

    mkdir -p "${HOME}/.config/pulse"
    cat > "${HOME}/.config/pulse/default.pa" << 'EOF'
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
load-module module-always-sink
EOF

    mark_step_done "audio"
    print_status ok "PulseAudio configured"
    log "INFO" "PulseAudio configured"
}

# ========== Step 7: Create Launcher Commands ==========
step_create_launchers() {
    step_header 7 9 "Creating Launcher Commands"

    if is_step_done "launchers"; then
        print_status info "Already created, skipping"
        return
    fi

    mkdir -p "${PREFIX}/bin"

    cat > "${PREFIX}/bin/debian" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
exec proot-distro login debian
EOF

    cat > "${PREFIX}/bin/debian-gui" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null 2>&1 &

sleep 3

proot-distro login debian --shared-tmp -- bash -c "
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
dbus-launch startxfce4
"
EOF

    chmod +x "${PREFIX}/bin/debian" "${PREFIX}/bin/debian-gui"

    if [[ ! -x "${PREFIX}/bin/debian" ]] || [[ ! -x "${PREFIX}/bin/debian-gui" ]]; then
        print_status error "Failed to create launcher scripts"
        exit 1
    fi

    mark_step_done "launchers"
    print_status ok "Launchers created: debian, debian-gui"
    log "INFO" "Launchers created"
}

# ========== Step 8: Verify Commands ==========
step_verify_commands() {
    step_header 8 9 "Verifying Commands"

    if ! command -v debian &>/dev/null; then
        print_status warn "'debian' not in PATH — adding fallback"

        mkdir -p "${HOME}/bin"
        ln -sf "${PREFIX}/bin/debian" "${HOME}/bin/debian" 2>/dev/null || true
        ln -sf "${PREFIX}/bin/debian-gui" "${HOME}/bin/debian-gui" 2>/dev/null || true

        if ! grep -q 'HOME/bin' "${HOME}/.bashrc" 2>/dev/null; then
            echo '' >> "${HOME}/.bashrc"
            echo '# termux-debian-auto' >> "${HOME}/.bashrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "${HOME}/.bashrc"
        fi

        print_status ok "Fallback created in ~/bin/"
    fi

    # Verify inside proot
    print_status info "Checking Debian Trixie version..."
    local version
    version=$(proot-distro login debian -- bash -c "cat /etc/debian_version 2>/dev/null || echo 'unknown'" 2>/dev/null)
    if echo "$version" | grep -qi "trixie\|testing\|13"; then
        print_status ok "Debian Trixie confirmed: ${version}"
    else
        print_status info "Debian version: ${version}"
    fi

    print_status ok "Verification complete"
    log "INFO" "Verification complete"
}

# ========== Step 9: Finalize ==========
step_finalize() {
    step_header 9 9 "Complete"

    print_status ok "Installation complete!"
    log "INFO" "Installation completed successfully"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Debian Trixie is ready!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}debian${NC}       - Enter Debian Trixie CLI"
    echo -e "  ${YELLOW}debian-gui${NC}   - Launch XFCE4 desktop (requires Termux-X11 APK)"
    echo ""
    echo -e "${BLUE}[i]${NC} Prerequisites:"
    echo -e "    • Termux from F-Droid: https://f-droid.org/packages/com.termux/"
    echo -e "    • Termux-X11 APK:      https://github.com/termux/termux-x11/releases"
    echo ""
    echo -e "${YELLOW}[!]${NC} If 'debian' command not found, run:"
    echo -e "    ${GREEN}source ~/.bashrc${NC}"
    echo ""
}

# ========== Main ==========
main() {
    clear
    echo -e "${BLUE}"
    cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║          termux-debian-auto — Debian Trixie for Termux      ║
║                   One-shot installer                        ║
║  github.com/highoncomputers/termux-debian-auto              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "${BLUE}[i]${NC} Log: ${LOG_FILE}"
    echo ""

    step_system_check
    step_install_deps
    step_install_trixie
    step_configure_debian
    step_configure_xfce4
    step_configure_audio
    step_create_launchers
    step_verify_commands
    step_finalize
}

main "$@"
