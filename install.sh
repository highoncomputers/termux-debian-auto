#!/data/data/com.termux/files/usr/bin/bash
# termux-debian-auto - One-shot Debian Trixie + XFCE4 installer for Termux
# Repository: https://github.com/highoncomputers/termux-debian-auto
# License: GPL-3.0
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash

set -euo pipefail

# ========== Configuration ==========
DEBIAN_USER="debian"
LOG_FILE="${HOME}/termux-debian-auto.log"
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

run_in_debian() {
    local cmd="$1"
    log "INFO" "Running in Debian: $cmd"
    if ! proot-distro login debian --shared-tmp -- /bin/bash -c "$cmd"; then
        print_status error "Failed in Debian: $cmd"
        log "ERROR" "Failed in Debian: $cmd"
        return 1
    fi
}

# ========== Step 1: System Check ==========
step_system_check() {
    print_status info "Checking system compatibility..."

    if [[ ! -d /data/data/com.termux ]]; then
        print_status error "This script must be run inside Termux on Android"
        exit 1
    fi

    local arch
    arch=$(uname -m)
    if [[ "$arch" != "aarch64" && "$arch" != "armv7l" && "$arch" != "x86_64" ]]; then
        print_status warn "Architecture '$arch' may not be fully supported (ARM64 recommended)"
    else
        print_status ok "Architecture: $arch"
    fi

    local storage_avail
    storage_avail=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $storage_avail -lt 4000000 ]]; then
        print_status error "Insufficient storage (need 4GB+, have $((storage_avail/1024))MB)"
        exit 1
    fi
    print_status ok "Storage: $((storage_avail/1024))MB available"

    if proot-distro list 2>/dev/null | grep -q "^debian"; then
        print_status warn "Debian proot-distro already installed — will reinstall"
        proot-distro remove debian 2>/dev/null || true
    fi

    print_status ok "System check passed"
    log "INFO" "System check passed"
}

# ========== Step 2: Install Termux Dependencies ==========
step_install_deps() {
    print_status info "Updating Termux packages..."

    retry "pkg update -y -o Dpkg::Options::=\"--force-confold\" 2>&1 | tail -5"

    if [[ ! -d ~/storage ]]; then
        print_status info "Setting up storage access..."
        termux-setup-storage 2>/dev/null || print_status warn "Storage setup skipped (non-fatal)"
    fi

    retry "pkg upgrade -y -o Dpkg::Options::=\"--force-confold\" 2>&1 | tail -5"

    print_status info "Installing Termux packages..."
    log "INFO" "Installing Termux packages"

    local packages=(
        proot-distro
        termux-x11-nightly
        pulseaudio
        virglrenderer-android
        dbus
        wget
        xfce4
        xfce4-terminal
    )

    local failed=()
    local count=0
    local total=${#packages[@]}

    for pkg in "${packages[@]}"; do
        ((count++))
        print_status info "[${count}/${total}] Installing $pkg..."
        if ! retry "pkg install -y $pkg -o Dpkg::Options::=\"--force-confold\" 2>&1 | tail -3"; then
            print_status warn "Failed to install $pkg"
            log "WARN" "Failed to install $pkg"
            failed+=("$pkg")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        print_status warn "Some packages failed: ${failed[*]}"
        print_status warn "Install them manually: pkg install ${failed[*]}"
    fi

    print_status ok "Termux packages installed"
    log "INFO" "Termux packages installed"
}

# ========== Step 3: Install Debian + Upgrade to Trixie ==========
step_install_debian() {
    print_status info "Installing Debian via proot-distro..."
    log "INFO" "Installing Debian proot-distro"

    if ! retry "proot-distro install debian 2>&1 | tail -5"; then
        print_status error "Failed to install Debian proot-distro"
        exit 1
    fi

    if [[ ! -d "$ROOTFS" ]]; then
        print_status error "Debian rootfs not found at $ROOTFS"
        exit 1
    fi
    print_status ok "Debian rootfs installed"

    print_status info "Migrating Debian Bookworm → Trixie..."
    log "INFO" "Upgrading sources.list to Trixie"

    run_in_debian "sed -i 's/bookworm/trixie/g' /etc/apt/sources.list 2>/dev/null; sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/*.list 2>/dev/null; rm -f /etc/apt/sources.list.d/debian.sources 2>/dev/null; echo 'deb http://deb.debian.org/debian trixie main contrib non-free-firmware' > /etc/apt/sources.list"

    print_status info "Updating Trixie package lists..."
    if ! retry "run_in_debian 'apt update 2>&1 | tail -5'"; then
        print_status error "Failed to update Trixie package lists"
        exit 1
    fi

    print_status info "Dist-upgrading to Trixie (this may take a while)..."
    if ! run_in_debian "DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y 2>&1 | tail -10"; then
        print_status error "Failed to dist-upgrade to Trixie"
        exit 1
    fi

    print_status ok "Debian upgraded to Trixie"
    log "INFO" "Debian upgraded to Trixie"
}

# ========== Step 4: Configure Debian User & Packages ==========
step_setup_debian_user() {
    print_status info "Configuring Debian user and packages..."
    log "INFO" "Configuring Debian user and packages"

    local deb_packages=(
        sudo
        dbus-x11
        xfce4
        xfce4-goodies
        firefox-esr
        pavucontrol-qt
        curl
    )

    print_status info "Installing Debian packages..."
    if ! run_in_debian "DEBIAN_FRONTEND=noninteractive apt install -y ${deb_packages[*]} 2>&1 | tail -5"; then
        print_status warn "Some Debian packages may not have installed"
    fi

    print_status info "Creating user '$DEBIAN_USER'..."
    run_in_debian "groupadd -f storage 2>/dev/null; groupadd -f wheel 2>/dev/null; useradd -m -g users -G wheel,audio,video,storage -s /bin/bash $DEBIAN_USER 2>/dev/null || true"

    print_status info "Configuring sudo (NOPASSWD)..."
    run_in_debian "echo '$DEBIAN_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$DEBIAN_USER && chmod 440 /etc/sudoers.d/$DEBIAN_USER"

    print_status info "Setting DISPLAY in .bashrc..."
    run_in_debian "echo 'export DISPLAY=:1' >> /home/$DEBIAN_USER/.bashrc"
    run_in_debian "echo 'export PULSE_SERVER=127.0.0.1' >> /home/$DEBIAN_USER/.bashrc"

    print_status ok "Debian user configured"
    log "INFO" "Debian user configured"
}

# ========== Step 5: Configure XFCE4 GUI ==========
step_setup_gui() {
    print_status info "Configuring XFCE4 desktop..."
    log "INFO" "Configuring XFCE4 desktop"

    if [[ ! -d "${DEBIAN_HOME}" ]]; then
        print_status error "Debian home not found: ${DEBIAN_HOME}"
        return 1
    fi

    mkdir -p "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml" \
             "${DEBIAN_HOME}/.config/xfce4/terminal" \
             "${DEBIAN_HOME}/.config/gtk-3.0"

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'XFCEDESK'
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
  <property name="desktop-icons" type="empty">
    <property name="file-icons" type="empty">
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-home" type="bool" value="true"/>
      <property name="show-trash" type="bool" value="true"/>
    </property>
  </property>
</channel>
XFCEDESK

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'XSETTINGS'
<?xml version="1.1" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
XSETTINGS

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'XFWM4'
<?xml version="1.1" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Adwaita"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="workspace_count" type="int" value="1"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="borderless_maximize" type="bool" value="true"/>
  </property>
</channel>
XFWM4

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" << 'XFCEPANEL'
<?xml version="1.1" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="icon-size" type="uint" value="0"/>
      <property name="size" type="uint" value="30"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-title" type="string" value="Menu"/>
    </property>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-4" type="string" value="clock">
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%b %d  %I:%M %p"/>
    </property>
    <property name="plugin-5" type="string" value="systray"/>
  </property>
</channel>
XFCEPANEL

    cat > "${DEBIAN_HOME}/.config/xfce4/terminal/terminalrc" << 'TERMINALRC'
[Configuration]
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=80x24
MiscMenubarDefault=TRUE
MiscMouseWheelZoom=TRUE
MiscConfirmClose=TRUE
MiscTabCloseButtons=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscCopyOnSelect=FALSE
MiscRewrapOnResize=TRUE
MiscSlimTabs=FALSE
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.850000
ColorBackground=#291f291f340d
TitleMode=TERMINAL_TITLE_HIDE
ScrollingUnlimited=TRUE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
FontName=Monospace 12
TERMINALRC

    cat > "${DEBIAN_HOME}/.config/gtk-3.0/settings.ini" << 'GTKINI'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
GTKINI

    chown -R 1000:1000 "${DEBIAN_HOME}/.config" 2>/dev/null || true

    print_status ok "XFCE4 desktop configured"
    log "INFO" "XFCE4 desktop configured"
}

# ========== Step 6: Configure PulseAudio ==========
step_setup_audio() {
    print_status info "Configuring PulseAudio..."
    log "INFO" "Configuring PulseAudio"

    cat > "${HOME}/.sound" << 'SOUNDEOF'
#!/data/data/com.termux/files/usr/bin/bash
pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1
SOUNDEOF
    chmod +x "${HOME}/.sound"

    print_status ok "PulseAudio configured"
    log "INFO" "PulseAudio configured"
}

# ========== Step 7: Configure VirGL Acceleration ==========
step_setup_accel() {
    print_status info "Configuring VirGL GPU acceleration..."
    log "INFO" "Configuring VirGL"

    cat > "${HOME}/.virgl" << 'VIRGLEOF'
#!/data/data/com.termux/files/usr/bin/bash
GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 virgl_test_server_android &
VIRGLEOF
    chmod +x "${HOME}/.virgl"

    print_status ok "VirGL configured"
    log "INFO" "VirGL configured"
}

# ========== Step 8: Create Launcher Commands ==========
step_create_launchers() {
    print_status info "Creating launcher commands..."
    log "INFO" "Creating launcher commands"

    cat > "${PREFIX}/bin/debian" << 'LAUNCHER_CLI'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
proot-distro login debian --user debian --shared-tmp -- /bin/bash
LAUNCHER_CLI

    cat > "${PREFIX}/bin/debian-gui" << 'LAUNCHER_GUI'
#!/data/data/com.termux/files/usr/bin/bash
# Debian GUI launcher - XFCE4 desktop via Termux X11
set -euo pipefail

LOG="${HOME}/debian-gui.log"

cleanup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up..." >> "$LOG"
    pkill -9 -f "termux-x11" 2>/dev/null || true
    pkill -9 -f "proot-distro.*debian" 2>/dev/null || true
    pkill -9 -f "virgl_test_server" 2>/dev/null || true
    pkill -9 -f "pulseaudio" 2>/dev/null || true
    sleep 2
}

cleanup

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting PulseAudio..." >> "$LOG"
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 >> "$LOG" 2>&1
export PULSE_SERVER=127.0.0.1

export XDG_RUNTIME_DIR="${TMPDIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting termux-x11..." >> "$LOG"
termux-x11 :1 >/dev/null 2>&1 &
sleep 3

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
sleep 2

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting VirGL..." >> "$LOG"
GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 virgl_test_server_android &>/dev/null &

TMPDIR_SAVED="${TMPDIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Debian Trixie XFCE4..." >> "$LOG"
proot-distro login debian --user debian --shared-tmp -- \
    /bin/bash -c "export DISPLAY=:1 && export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\"${TMPDIR_SAVED}\" && dbus-launch --exit-with-session startxfce4"
LAUNCHER_GUI

    chmod +x "${PREFIX}/bin/debian" "${PREFIX}/bin/debian-gui"

    if [[ ! -x "${PREFIX}/bin/debian" ]] || [[ ! -x "${PREFIX}/bin/debian-gui" ]]; then
        print_status error "Failed to create launcher scripts"
        exit 1
    fi

    print_status ok "Launchers created: debian, debian-gui"
    log "INFO" "Launchers created at ${PREFIX}/bin/"
}

# ========== Step 9: Finalize ==========
step_finalize() {
    print_status info "Finalizing..."
    log "INFO" "Finalizing installation"

    local bashrc="${HOME}/.bashrc"
    local aliases_added=0

    if [[ -f "$bashrc" ]]; then
        if ! grep -q "alias debian=" "$bashrc" 2>/dev/null; then
            echo "" >> "$bashrc"
            echo "# termux-debian-auto" >> "$bashrc"
            echo "alias debian='${PREFIX}/bin/debian'" >> "$bashrc"
            echo "alias debian-gui='${PREFIX}/bin/debian-gui'" >> "$bashrc"
            aliases_added=1
        fi
    fi

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
    echo -e "${BLUE}[i]${NC} Prerequisites (install these first):"
    echo -e "    • Termux-X11 APK: https://github.com/termux/termux-x11/releases"
    echo -e "    • The 'termux-x11' app must be installed as a regular Android app"
    echo ""
    echo -e "${YELLOW}[!]${NC} Restart Termux or run: ${GREEN}source ~/.bashrc${NC}"
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
    step_install_debian
    step_setup_debian_user
    step_setup_gui
    step_setup_audio
    step_setup_accel
    step_create_launchers
    step_finalize
}

main "$@"
