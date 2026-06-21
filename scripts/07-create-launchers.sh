#!/data/data/com.termux/files/usr/bin/bash
# Create debian and debian-gui launcher scripts (fixed version)

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

validate_launchers() {
    local prefix="${PREFIX}"
    
    if [[ ! -d "$prefix/bin" ]]; then
        print_status error "PREFIX/bin directory not found: $prefix/bin"
        log "ERROR" "PREFIX/bin directory not found: $prefix/bin"
        return 1
    fi
    
    if [[ ! -x "$prefix/bin/debian" ]]; then
        print_status error "debian launcher not found or not executable: $prefix/bin/debian"
        log "ERROR" "debian launcher not found or not executable: $prefix/bin/debian"
        return 1
    fi
    
    if [[ ! -x "$prefix/bin/debian-gui" ]]; then
        print_status error "debian-gui launcher not found or not executable: $prefix/bin/debian-gui"
        log "ERROR" "debian-gui launcher not found or not executable: $prefix/bin/debian-gui"
        return 1
    fi
    
    print_status ok "Launchers validated"
    return 0
}

main() {
    print_status info "Creating launcher commands..."
    log "INFO" "Creating debian and debian-gui launcher commands"

    # debian CLI launcher (fixed - no exec to allow returning to Termux)
    cat > "${PREFIX}/bin/debian" << 'DEBIANEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Debian CLI launcher - quick entry to Debian proot environment
set -euo pipefail
proot-distro login debian --user debian --shared-tmp -- /bin/bash
DEBIANEOF

    # debian-gui launcher (kills existing sessions, starts fresh)
    cat > "${PREFIX}/bin/debian-gui" << 'DEBIANX11EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Debian GUI launcher - starts XFCE4 desktop via Termux X11
# Automatically kills any existing X11/proot/pulseaudio/virgl sessions first
set -euo pipefail

LOG="${HOME}/debian-gui.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting debian-gui..." >> "${LOG}"

# Kill all existing sessions
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Killing existing sessions..." >> "${LOG}"
pkill -9 -f "termux-x11" 2>/dev/null || true
pkill -9 -f "proot-distro.*debian" 2>/dev/null || true
pkill -9 -f "virgl_test_server" 2>/dev/null || true
pkill -9 -f "pulseaudio" 2>/dev/null || true
sleep 2

# Start PulseAudio
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting PulseAudio..." >> "${LOG}"
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 >> "${LOG}" 2>&1
export PULSE_SERVER=127.0.0.1

# Prepare X11
export XDG_RUNTIME_DIR="${TMPDIR}"

# Start termux-x11 on display :1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting termux-x11..." >> "${LOG}"
termux-x11 :1 >/dev/null 2>&1 &
sleep 3

# Launch Termux X11 activity
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Termux X11 activity..." >> "${LOG}"
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 2

# Start virglrenderer for GPU acceleration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting VirGL..." >> "${LOG}"
GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 virgl_test_server_android &>/dev/null &

# Pass TMPDIR to inner shell for proper XDG_RUNTIME_DIR
TMPDIR_SAVED="${TMPDIR}"

# Login to Debian and launch XFCE4
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Debian XFCE4..." >> "${LOG}"
proot-distro login debian --user debian --shared-tmp -- \
    /bin/bash -c "export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\"${TMPDIR_SAVED}\" && dbus-launch --exit-with-session startxfce4"
DEBIANX11EOF

    chmod +x "${PREFIX}/bin/debian" "${PREFIX}/bin/debian-gui"

    print_status info "Validating launchers..."
    if ! validate_launchers; then
        exit 1
    fi

    print_status ok "Launchers created: debian, debian-gui"
    log "INFO" "Launchers created successfully"
}

main "$@"