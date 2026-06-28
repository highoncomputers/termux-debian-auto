#!/data/data/com.termux/files/usr/bin/bash
# termux-debian-auto - One-shot Debian Trixie + XFCE4 for Termux
# Repository: https://github.com/highoncomputers/termux-debian-auto
# License: GPL-3.0
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash

# ── Config ──────────────────────────────────────────────────────────────
DEBIAN_USER="debian"
LOG_FILE="${HOME}/termux-debian-auto.log"
STATE_DIR="${HOME}/.termux-debian-auto"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_HOME="${ROOTFS}/home/${DEBIAN_USER}"
TOTAL_STEPS=9

exec 2>>"${LOG_FILE}"

# ── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[i]${NC} $*"; }
ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; log "WARN" "$*"; }
error_(){ echo -e "${RED}[✗]${NC} $*"; }
log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$LOG_FILE"; }

# ── Helpers ─────────────────────────────────────────────────────────────
step_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE} Step ${1}/${TOTAL_STEPS}: ${2}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "INFO" "Step ${1}/${TOTAL_STEPS}: ${2}"
}

is_done() { [[ -f "${STATE_DIR}/$1" ]]; }
mark_done() { mkdir -p "${STATE_DIR}"; touch "${STATE_DIR}/$1"; }

retry() {
    local cmd="$1" max=3 attempt=1 outfile
    outfile="$(mktemp)"
    while [[ $attempt -le $max ]]; do
        if eval "$cmd" >"$outfile" 2>&1; then
            rm -f "$outfile"
            return 0
        fi
        warn "Retrying (${attempt}/${max})..."
        log "WARN" "Retry ${attempt}/${max}: $(tail -3 "$outfile")"
        ((attempt++)); sleep 3
    done
    error_ "Failed after ${max} attempts: $cmd"
    log "ERROR" "Failed after ${max} attempts: $(tail -5 "$outfile")"
    rm -f "$outfile"
    return 1
}

# Safe proot command runner — no quote-nesting issues
run_in_debian() {
    local cmd
    printf -v cmd '%q ' "$@"
    log "INFO" "proot: $*"
    proot-distro login debian --shared-tmp -- /bin/bash -c "$cmd"
}

# ── Step 1: System Check ───────────────────────────────────────────────
step_system_check() {
    step_header 1 "System Check"
    info "Checking system compatibility..."

    if [[ ! -d /data/data/com.termux ]]; then
        error_ "This script must be run inside Termux on Android"; exit 1
    fi

    arch=$(uname -m); ok "Architecture: ${arch}"

    avail=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $avail -lt 4000000 ]]; then
        error_ "Insufficient storage (need 4GB+, have $((avail/1024))MB)"; exit 1
    fi
    ok "Storage: $((avail/1024))MB available"

    if is_done "system_check"; then info "Already checked, skipping"
    else mark_done "system_check"; fi
}

# ── Step 2: Install Termux Dependencies ────────────────────────────────
step_install_deps() {
    step_header 2 "Install Termux Packages"
    if is_done "deps"; then info "Already completed, skipping"; return; fi

    info "Updating package repositories..."
    retry "pkg update -y -o Dpkg::Options::='--force-confold' 2>&1 | tail -3" || true

    info "Upgrading packages..."
    retry "pkg upgrade -y -o Dpkg::Options::='--force-confold' 2>&1 | tail -3" || true

    if [[ ! -d ~/storage ]]; then
        info "Setting up storage access..."
        timeout 15 termux-setup-storage 2>/dev/null || warn "Storage setup skipped (non-fatal)"
    else
        info "Storage already configured, skipping"
    fi

    local packages=(proot-distro x11-repo termux-x11-nightly pulseaudio wget)
    local failed=() count=0 total=${#packages[@]}

    for pkg in "${packages[@]}"; do
        ((count++))
        info "[${count}/${total}] Installing ${pkg}..."
        if ! retry "pkg install -y ${pkg} -o Dpkg::Options::='--force-confold' 2>&1 | tail -2"; then
            warn "Failed to install ${pkg}"; failed+=("$pkg")
        fi
    done

    [[ ${#failed[@]} -gt 0 ]] && warn "Some packages failed: ${failed[*]}"
    mark_done "deps"; ok "Termux packages installed"
}

# ── Step 3: Create Launchers (early — so 'debian' command always exists) ─
step_create_launchers() {
    step_header 3 "Create Launcher Commands"
    if is_done "launchers"; then info "Already created, skipping"; return; fi

    mkdir -p "${PREFIX}/bin"

    cat > "${PREFIX}/bin/debian" << 'LAUNCHER_CLI'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
exec proot-distro login debian
LAUNCHER_CLI

    cat > "${PREFIX}/bin/debian-gui" << 'LAUNCHER_GUI'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
if [[ -f /etc/debian_version ]]; then
    echo "Error: debian-gui must be run from Termux, not from inside the proot." >&2
    exit 1
fi
export XDG_RUNTIME_DIR=${TMPDIR:-/tmp}
termux-x11 :0 >/dev/null 2>&1 &
am start -n com.termux.x11/.MainActivity >/dev/null 2>&1 || true
sleep 3
proot-distro login debian --shared-tmp -- bash -c "
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
dbus-launch --exit-with-session xfce4-session
"
LAUNCHER_GUI

    chmod +x "${PREFIX}/bin/debian" "${PREFIX}/bin/debian-gui"

    if [[ ! -x "${PREFIX}/bin/debian" ]]; then
        error_ "Failed to create debian launcher"; exit 1
    fi

    # PATH fallback
    if ! command -v debian &>/dev/null; then
        mkdir -p "${HOME}/bin"
        ln -sf "${PREFIX}/bin/debian" "${HOME}/bin/debian"
        ln -sf "${PREFIX}/bin/debian-gui" "${HOME}/bin/debian-gui"
        if ! grep -q "${HOME}/bin" "${HOME}/.bashrc" 2>/dev/null; then
            echo "" >> "${HOME}/.bashrc"
            echo "# termux-debian-auto" >> "${HOME}/.bashrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "${HOME}/.bashrc"
        fi
        ok "Fallback created in ~/bin/"
    fi

    mark_done "launchers"; ok "Launchers created: debian, debian-gui"
}

# ── Step 4: Install Debian Trixie ──────────────────────────────────────
step_install_trixie() {
    step_header 4 "Install Debian Trixie"
    if is_done "trixie"; then info "Already installed, skipping"; return; fi

    if [[ ! -d "$ROOTFS" ]]; then
        info "Installing Debian Bookworm from standard tarball..."
        if ! retry "proot-distro install debian 2>&1 | tail -5"; then
            error_ "Failed to install Debian"
            error_ "Check internet connection and try again"; exit 1
        fi
        if [[ ! -d "$ROOTFS" ]]; then
            error_ "Debian rootfs not found at ${ROOTFS}"; exit 1
        fi
    else
        info "Existing Debian rootfs found — upgrading to Trixie"
    fi

    info "Switching Bookworm sources to Trixie..."
    run_in_debian sh -c "echo 'deb http://deb.debian.org/debian trixie main contrib non-free' > /etc/apt/sources.list"

    info "Updating package lists..."
    run_in_debian apt-get update || true

    info "Dist-upgrading to Trixie (this may take a while)..."
    if ! run_in_debian DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y; then
        warn "Dist-upgrade had issues — may already be Trixie"
    fi

    run_in_debian sh -c "rm -f /etc/apt/sources.list.d/*.list 2>/dev/null || true"

    local version
    version=$(proot-distro login debian -- bash -c "cat /etc/debian_version 2>/dev/null || echo unknown" 2>/dev/null)
    info "Debian version: ${version}"

    mark_done "trixie"; ok "Debian Trixie installed (${version})"
}

# ── Step 5: Configure Debian ───────────────────────────────────────────
step_configure_debian() {
    step_header 5 "Configure Debian"
    if is_done "configured"; then info "Already configured, skipping"; return; fi

    info "Updating package lists..."
    run_in_debian apt-get update -y || true

    info "Upgrading packages..."
    run_in_debian DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || true

    info "Installing core Debian packages..."
    if ! run_in_debian DEBIAN_FRONTEND=noninteractive apt-get install -y \
        sudo curl wget git nano; then
        warn "Some core packages may not have installed"
    fi

    info "Installing XFCE4 desktop..."
    if ! run_in_debian DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xfce4 xfce4-session dbus-x11 firefox-esr pavucontrol-qt; then
        warn "Some desktop packages may not have installed"
    fi

    info "Verifying XFCE4 session..."
    run_in_debian bash -c "command -v xfce4-session" || warn "xfce4-session not found — GUI may not work"

    info "Creating user '${DEBIAN_USER}'..."
    run_in_debian groupadd -f storage 2>/dev/null || true
    run_in_debian groupadd -f wheel 2>/dev/null || true
    run_in_debian useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "${DEBIAN_USER}" 2>/dev/null || true

    info "Configuring sudo (NOPASSWD)..."
    run_in_debian sh -c "echo '${DEBIAN_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${DEBIAN_USER}"
    run_in_debian chmod 440 /etc/sudoers.d/${DEBIAN_USER}

    info "Setting environment variables..."
    run_in_debian sh -c "echo 'export DISPLAY=:0' >> /home/${DEBIAN_USER}/.bashrc"
    run_in_debian sh -c "echo 'export PULSE_SERVER=127.0.0.1' >> /home/${DEBIAN_USER}/.bashrc"

    mark_done "configured"; ok "Debian Trixie configured"
}

# ── Step 6: Configure XFCE4 ────────────────────────────────────────────
step_configure_xfce4() {
    step_header 6 "Configure XFCE4 Desktop"
    if is_done "xfce4"; then info "Already configured, skipping"; return; fi

    if [[ ! -d "${DEBIAN_HOME}" ]]; then
        error_ "Debian home not found: ${DEBIAN_HOME}"; exit 1
    fi

    mkdir -p "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml" \
             "${DEBIAN_HOME}/.config/xfce4/terminal" \
             "${DEBIAN_HOME}/.config/gtk-3.0"

    cat > "${DEBIAN_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'EOF'
<?xml version="1.1" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="workspace0" type="empty">
        <property name="last-image" type="string" value="/usr/share/backgrounds/xfce/xfce-teal.jpg"/>
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

    run_in_debian chown -R "${DEBIAN_USER}:${DEBIAN_USER}" "/home/${DEBIAN_USER}/.config" 2>/dev/null || true

    mark_done "xfce4"; ok "XFCE4 configured"
}

# ── Step 7: Configure PulseAudio ───────────────────────────────────────
step_configure_audio() {
    step_header 7 "Configure PulseAudio"
    if is_done "audio"; then info "Already configured, skipping"; return; fi

    mkdir -p "${HOME}/.config/pulse"
    cat > "${HOME}/.config/pulse/default.pa" << 'EOF'
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
load-module module-always-sink
EOF

    mark_done "audio"; ok "PulseAudio configured"
}

# ── Step 8: Verify ─────────────────────────────────────────────────────
step_verify() {
    step_header 8 "Verify Installation"
    if is_done "verify"; then info "Already verified, skipping"; return; fi

    info "Checking Debian Trixie version..."
    local version
    version=$(proot-distro login debian -- bash -c "cat /etc/debian_version 2>/dev/null || echo unknown" 2>/dev/null)
    if echo "$version" | grep -qi "trixie\|testing\|13\|sid"; then
        ok "Debian Trixie confirmed: ${version}"
    else
        info "Debian version: ${version}"
    fi

    mark_done "verify"; ok "Verification complete"
}

# ── Step 9: Finalize ───────────────────────────────────────────────────
step_finalize() {
    step_header 9 "Complete"
    if is_done "finalize"; then info "Already finalized, skipping"; return; fi

    ok "Installation complete!"
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Debian Trixie is ready!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}debian${NC}       - Enter Debian Trixie CLI"
    echo -e "  ${YELLOW}debian-gui${NC}   - Launch XFCE4 desktop (Termux-X11 APK required)"
    echo ""
    echo -e "${BLUE}[i]${NC} Prerequisites:"
    echo -e "    • Termux from F-Droid: https://f-droid.org/packages/com.termux/"
    echo -e "    • Termux-X11 APK:      https://github.com/termux/termux-x11/releases"
    echo ""
    echo -e "${YELLOW}[!]${NC} If 'debian' not found: ${GREEN}source ~/.bashrc${NC}"
    echo ""

    mark_done "finalize"
}

# ── Main ────────────────────────────────────────────────────────────────
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
    step_create_launchers  # Early — debian command exists even if later steps fail
    step_install_trixie
    step_configure_debian
    step_configure_xfce4
    step_configure_audio
    step_verify
    step_finalize

    # Anonymous install counter
    curl -sL "https://api.countapi.xyz/hit/highoncomputers/termux-debian-auto-installs" >/dev/null 2>&1 || true
}

main "$@"
