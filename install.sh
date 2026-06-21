#!/data/data/com.termux/files/usr/bin/bash
# termux-debian-auto - Fully automated Debian + XFCE4 installer for Termux
# Repository: https://github.com/highoncomputers/termux-debian-auto
# License: GPL-3.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_OWNER="highoncomputers"
REPO_NAME="termux-debian-auto"
REPO_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

# Logging
LOG_FILE="${HOME}/termux-debian-auto.log"
exec 2>>"${LOG_FILE}"

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

run_script() {
    local script_name=$1
    local script_url="${BASE_URL}/scripts/${script_name}"
    print_status info "Running ${script_name}..."
    if curl -sL "${script_url}" | bash; then
        print_status ok "${script_name} completed"
    else
        print_status error "${script_name} failed"
        exit 1
    fi
}

main() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║           termux-debian-auto Installer                       ║
║  Automated Debian + XFCE4 Desktop for Termux                ║
║  Repository: github.com/highoncomputers/termux-debian-auto  ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    print_status info "Starting installation... (log: ${LOG_FILE})"
    echo

    # Run all installation scripts in order
    run_script "01-system-check.sh"
    run_script "02-install-deps.sh"
    run_script "03-install-debian.sh"
    run_script "04-setup-gui.sh"
    run_script "05-setup-audio.sh"
    run_script "06-setup-accel.sh"
    run_script "07-create-launchers.sh"
    run_script "08-finalize.sh"

    echo
    print_status ok "Installation complete!"
    echo
    echo -e "${GREEN}Usage:${NC}"
    echo -e "  ${YELLOW}debian${NC}      - Enter Debian CLI environment"
    echo -e "  ${YELLOW}debian-gui${NC}  - Launch XFCE4 desktop (kills existing sessions)"
    echo
    echo -e "${BLUE}Note:${NC} Termux-X11 APK must be installed from GitHub releases"
    echo -e "${BLUE}      ${NC}https://github.com/termux/termux-x11/releases"
}

main "$@"