#!/data/data/com.termux/files/usr/bin/bash
# termux-debian-auto - One-shot Debian Trixie + XFCE4 for Termux
# Repository: https://github.com/highoncomputers/termux-debian-auto
# License: GPL-3.0
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash

set -euo pipefail

if ! command -v python3 &>/dev/null; then
    echo "[...] Installing Python..."
    pkg install -y python 2>&1 | tail -3
fi

exec python3 - "$@" << 'PYEOF'
#!/usr/bin/env python3
"""termux-debian-auto — Debian Trixie + XFCE4 installer for Termux"""

import json
import logging
import os
import re
import shutil
import signal
import subprocess
import sys
import textwrap
import time
from datetime import datetime, timezone
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────
DEBIAN_USER = "debian"
HOME = Path.home()
STATE_DIR = HOME / ".termux-debian-auto"
STATE_FILE = STATE_DIR / "state.json"
LOG_FILE = HOME / "termux-debian-auto.log"
PREFIX = Path(os.environ.get("PREFIX", "/data/data/com.termux/files/usr"))
ROOTFS = PREFIX / "var/lib/proot-distro/installed-rootfs" / "debian"
DEBIAN_HOME = ROOTFS / "home" / DEBIAN_USER

STEP_NAMES = [
    ("system_check", "System Check"),
    ("deps",         "Install Termux Packages"),
    ("trixie",       "Install Debian Trixie"),
    ("configured",   "Configure Debian"),
    ("xfce4",        "Configure XFCE4 Desktop"),
    ("audio",        "Configure PulseAudio"),
    ("launchers",    "Create Launcher Commands"),
    ("verify",       "Verify Installation"),
    ("finalize",     "Complete"),
]

TOTAL_STEPS = len(STEP_NAMES)

Colour = type("", (), {
    "RED": "\033[0;31m",
    "GREEN": "\033[0;32m",
    "YELLOW": "\033[1;33m",
    "BLUE": "\033[0;34m",
    "NC": "\033[0m",
    "BOLD": "\033[1m",
})()

# ── Setup logging ───────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(str(LOG_FILE)),
        logging.StreamHandler(sys.stderr),
    ],
)
log = logging.getLogger("installer")


def info(msg):
    print(f"{Colour.BLUE}[i]{Colour.NC} {msg}")


def ok(msg):
    print(f"{Colour.GREEN}[✓]{Colour.NC} {msg}")


def warn(msg):
    print(f"{Colour.YELLOW}[!]{Colour.NC} {msg}")


def error(msg):
    print(f"{Colour.RED}[✗]{Colour.NC} {msg}")


def step_header(current, name):
    print()
    print(f"{Colour.BLUE}{'━' * 47}{Colour.NC}")
    print(f"{Colour.BLUE} Step {current}/{TOTAL_STEPS}: {name}{Colour.NC}")
    print(f"{Colour.BLUE}{'━' * 47}{Colour.NC}")


# ── State management ────────────────────────────────────────────────────
class State:
    def __init__(self):
        self.data = self._load()

    def _load(self):
        if STATE_FILE.exists():
            try:
                with open(STATE_FILE) as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError):
                pass
        return {"steps": {}, "version": "2.0"}

    def save(self):
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with open(STATE_FILE, "w") as f:
            json.dump(self.data, f, indent=2)

    def is_done(self, step_id):
        return self.data.get("steps", {}).get(step_id, False)

    def mark_done(self, step_id):
        self.data.setdefault("steps", {})[step_id] = True
        self.data["last_step"] = step_id
        self.data["updated_at"] = datetime.now(timezone.utc).isoformat()
        self.save()


# ── Helpers ─────────────────────────────────────────────────────────────
def run(cmd, **kwargs):
    log.info("Running: %s", " ".join(str(c) if " " not in str(c) else f"'{c}'" for c in cmd))
    return subprocess.run(cmd, **kwargs)


def run_proot(cmd, capture=True, check=False):
    full = ["proot-distro", "login", "debian", "--", "bash", "-c", cmd]
    log.info("proot: %s", cmd)
    kw = {}
    if capture:
        kw["capture_output"] = True
        kw["text"] = True
    p = subprocess.run(full, **kw)
    if check and p.returncode != 0:
        raise RuntimeError(f"proot command failed (exit {p.returncode}): {cmd}")
    return p


def retry(cmd_fn, max_attempts=3, delay=3):
    for attempt in range(1, max_attempts + 1):
        try:
            result = cmd_fn()
            if result.returncode == 0:
                return result
        except Exception as e:
            log.warning("Attempt %d/%d failed: %s", attempt, max_attempts, e)
        if attempt < max_attempts:
            warn(f"Retrying ({attempt}/{max_attempts})...")
            time.sleep(delay)
    raise RuntimeError(f"Command failed after {max_attempts} attempts")


def pkg_install(pkg_name):
    cmd = ["pkg", "install", "-y", pkg_name,
           "-o", "Dpkg::Options::=--force-confold"]
    return run(cmd, capture_output=True, text=True)


def pkg_retry(pkg_name):
    return retry(lambda: pkg_install(pkg_name))


def write_file(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


# ── Steps ───────────────────────────────────────────────────────────────

def step_system_check(state):
    step_header(1, "System Check")
    info("Checking system compatibility...")

    if not Path("/data/data/com.termux").is_dir():
        error("This script must be run inside Termux on Android")
        sys.exit(1)

    arch = os.uname().machine
    ok(f"Architecture: {arch}")

    stat = os.statvfs(str(HOME))
    avail_mb = stat.f_frsize * stat.f_bavail // (1024 * 1024)
    if avail_mb < 4096:
        error(f"Insufficient storage (need 4096 MB, have {avail_mb} MB)")
        sys.exit(1)
    ok(f"Storage: {avail_mb} MB available")

    state.mark_done("system_check")


def step_install_deps(state):
    step_header(2, "Install Termux Packages")
    if state.is_done("deps"):
        info("Already completed, skipping")
        return

    info("Updating package repositories...")
    try:
        retry(lambda: run(["pkg", "update", "-y", "-o", "Dpkg::Options::=--force-confold"],
                           capture_output=True, text=True))
    except RuntimeError as e:
        warn(f"Update failed: {e}")

    info("Upgrading packages...")
    try:
        retry(lambda: run(["pkg", "upgrade", "-y", "-o", "Dpkg::Options::=--force-confold"],
                           capture_output=True, text=True))
    except RuntimeError as e:
        warn(f"Upgrade failed: {e}")

    # Storage access — check first, skip if exists
    storage_dir = HOME / "storage"
    if not storage_dir.is_dir():
        info("Setting up storage access...")
        try:
            p = run(["termux-setup-storage"], timeout=15, capture_output=True, text=True)
            if p.returncode != 0:
                warn(f"Storage setup returned non-zero: {p.stderr.strip() or p.stdout.strip()}")
        except subprocess.TimeoutExpired:
            warn("Storage setup timed out (non-fatal)")
        except FileNotFoundError:
            warn("termux-setup-storage not available (non-fatal)")
    else:
        info("Storage already configured, skipping")

    packages = ["proot-distro", "x11-repo", "termux-x11-nightly", "pulseaudio", "wget"]
    failed = []
    for i, pkg in enumerate(packages, 1):
        info(f"[{i}/{len(packages)}] Installing {pkg}...")
        try:
            pkg_retry(pkg)
        except RuntimeError:
            warn(f"Failed to install {pkg}")
            failed.append(pkg)

    if failed:
        warn(f"Some packages failed: {', '.join(failed)}")

    state.mark_done("deps")
    ok("Termux packages installed")


def step_install_trixie(state):
    step_header(3, "Install Debian Trixie")
    if state.is_done("trixie"):
        info("Already installed, skipping")
        return

    if ROOTFS.is_dir():
        warn("Debian rootfs already exists — removing")
        run(["proot-distro", "remove", "debian"], capture_output=True)
        shutil.rmtree(ROOTFS, ignore_errors=True)

    info("Pulling debian:trixie from Docker Hub...")

    def do_install():
        return run(["proot-distro", "install", "debian:trixie"], capture_output=True, text=True)

    try:
        retry(do_install, max_attempts=2)
    except RuntimeError as e:
        error("Failed to install Debian Trixie")
        error("Check internet connection and try again")
        sys.exit(1)

    # Verify rootfs
    if not ROOTFS.is_dir():
        error(f"Debian rootfs not found at {ROOTFS}")
        r = run(["proot-distro", "list"], capture_output=True, text=True)
        for line in r.stdout.splitlines():
            if "debian" in line.lower():
                name = line.strip().split()[0]
                warn(f"Found container '{name}' — renaming to 'debian'")
                run(["proot-distro", "rename", name, "debian"], capture_output=True)
                break
        else:
            error("No Debian container found. Try: proot-distro install debian:trixie")
            sys.exit(1)

    state.mark_done("trixie")
    ok("Debian Trixie installed")


def step_configure_debian(state):
    step_header(4, "Configure Debian")
    if state.is_done("configured"):
        info("Already configured, skipping")
        return

    info("Updating package lists...")
    try:
        retry(lambda: run_proot("apt-get update -y", check=False))
    except RuntimeError as e:
        warn(f"Update failed: {e}")

    info("Upgrading packages...")
    run_proot("DEBIAN_FRONTEND=noninteractive apt-get upgrade -y", check=False)

    info("Installing Debian packages (sudo, xfce4, firefox, etc.)...")
    install_pkgs = "sudo curl wget git nano xfce4 dbus-x11 firefox-esr pavucontrol-qt"
    p = run_proot(f"DEBIAN_FRONTEND=noninteractive apt-get install -y {install_pkgs}", check=False)
    if p.returncode != 0:
        warn("Some Debian packages may not have installed")

    info(f"Creating user '{DEBIAN_USER}'...")
    run_proot(
        f"groupadd -f storage 2>/dev/null; "
        f"groupadd -f wheel 2>/dev/null; "
        f"useradd -m -g users -G wheel,audio,video,storage -s /bin/bash {DEBIAN_USER} "
        f"2>/dev/null || echo 'User exists'"
    )

    info("Configuring sudo (NOPASSWD)...")
    run_proot(
        f"echo '{DEBIAN_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/{DEBIAN_USER} && "
        f"chmod 440 /etc/sudoers.d/{DEBIAN_USER}"
    )

    info("Setting environment variables in .bashrc...")
    run_proot(f"echo 'export DISPLAY=:0' >> /home/{DEBIAN_USER}/.bashrc")
    run_proot(f"echo 'export PULSE_SERVER=127.0.0.1' >> /home/{DEBIAN_USER}/.bashrc")

    state.mark_done("configured")
    ok("Debian Trixie configured")


def step_configure_xfce4(state):
    step_header(5, "Configure XFCE4 Desktop")
    if state.is_done("xfce4"):
        info("Already configured, skipping")
        return

    if not DEBIAN_HOME.is_dir():
        error(f"Debian home directory not found: {DEBIAN_HOME}")
        sys.exit(1)

    cfg = DEBIAN_HOME / ".config"
    xfce = cfg / "xfce4"
    xfconf = xfce / "xfconf" / "xfce-perchannel-xml"
    term_cfg = xfce / "terminal"
    gtk_cfg = cfg / "gtk-3.0"
    for d in [xfconf, term_cfg, gtk_cfg]:
        d.mkdir(parents=True, exist_ok=True)

    write_file(xfconf / "xfce4-desktop.xml", textwrap.dedent("""\
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
    """))

    write_file(xfconf / "xsettings.xml", textwrap.dedent("""\
        <?xml version="1.1" encoding="UTF-8"?>
        <channel name="xsettings" version="1.0">
          <property name="Net" type="empty">
            <property name="ThemeName" type="string" value="Adwaita-dark"/>
            <property name="IconThemeName" type="string" value="Adwaita"/>
          </property>
        </channel>
    """))

    write_file(term_cfg / "terminalrc", textwrap.dedent("""\
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
    """))

    write_file(gtk_cfg / "settings.ini", textwrap.dedent("""\
        [Settings]
        gtk-theme-name=Adwaita-dark
        gtk-icon-theme-name=Adwaita
        gtk-font-name=Sans 10
    """))

    run_proot(f"chown -R {DEBIAN_USER}:{DEBIAN_USER} /home/{DEBIAN_USER}/.config 2>/dev/null || true",
              check=False)

    state.mark_done("xfce4")
    ok("XFCE4 configured")


def step_configure_audio(state):
    step_header(6, "Configure PulseAudio")
    if state.is_done("audio"):
        info("Already configured, skipping")
        return

    pulse_cfg = HOME / ".config" / "pulse" / "default.pa"
    pulse_cfg.parent.mkdir(parents=True, exist_ok=True)
    write_file(pulse_cfg, textwrap.dedent("""\
        load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
        load-module module-always-sink
    """))

    state.mark_done("audio")
    ok("PulseAudio configured")


def step_create_launchers(state):
    step_header(7, "Create Launcher Commands")
    if state.is_done("launchers"):
        info("Already created, skipping")
        return

    bin_dir = PREFIX / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)

    debian_sh = textwrap.dedent("""\
        #!/data/data/com.termux/files/usr/bin/bash
        set -euo pipefail
        exec proot-distro login debian
    """)
    launcher_cli = bin_dir / "debian"
    launcher_cli.write_text(debian_sh)
    launcher_cli.chmod(0o755)

    gui_sh = textwrap.dedent("""\
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
    """)
    launcher_gui = bin_dir / "debian-gui"
    launcher_gui.write_text(gui_sh)
    launcher_gui.chmod(0o755)

    if not launcher_cli.is_file() or not launcher_gui.is_file():
        error("Failed to create launcher scripts")
        sys.exit(1)

    state.mark_done("launchers")
    ok("Launchers created: debian, debian-gui")


def step_verify(state):
    step_header(8, "Verify Installation")
    if state.is_done("verify"):
        info("Already verified, skipping")
        return

    # Check if 'debian' is in PATH
    debian_path = shutil.which("debian")
    if debian_path is None:
        warn("'debian' not in PATH — adding fallback")

        fallback_dir = HOME / "bin"
        fallback_dir.mkdir(parents=True, exist_ok=True)
        src = PREFIX / "bin" / "debian"
        dst = fallback_dir / "debian"
        if src.exists():
            dst.unlink(missing_ok=True)
            dst.symlink_to(src)

        src_gui = PREFIX / "bin" / "debian-gui"
        dst_gui = fallback_dir / "debian-gui"
        if src_gui.exists():
            dst_gui.unlink(missing_ok=True)
            dst_gui.symlink_to(src_gui)

        bashrc = HOME / ".bashrc"
        path_line = 'export PATH="$HOME/bin:$PATH"'
        if bashrc.exists() and path_line not in bashrc.read_text():
            with open(bashrc, "a") as f:
                f.write(f"\n# termux-debian-auto\n{path_line}\n")

        ok("Fallback created in ~/bin/")

    # Verify Debian version inside proot
    info("Checking Debian Trixie version...")
    p = run_proot("cat /etc/debian_version 2>/dev/null || echo 'unknown'", check=False)
    version = p.stdout.strip() if p.returncode == 0 else "unknown"
    if re.search(r"trixie|testing|13", version, re.IGNORECASE):
        ok(f"Debian Trixie confirmed: {version}")
    else:
        info(f"Debian version: {version}")

    state.mark_done("verify")
    ok("Verification complete")


def step_finalize(state):
    step_header(9, "Complete")
    state.mark_done("finalize")

    LOG_FILE.write_text(
        re.sub(r"\x1b\[[0-9;]*m", "", LOG_FILE.read_text())
    )

    ok("Installation complete!")

    print()
    print(f"{Colour.GREEN}{'╔' + '═' * 54 + '╗'}{Colour.NC}")
    print(f"{Colour.GREEN}║{'':>30} {'':<24}║{Colour.NC}")
    print(f"{Colour.GREEN}║{'   Debian Trixie is ready!':^55}║{Colour.NC}")
    print(f"{Colour.GREEN}║{'':>30} {'':<24}║{Colour.NC}")
    print(f"{Colour.GREEN}{'╚' + '═' * 54 + '╝'}{Colour.NC}")
    print()
    print(f"  {Colour.YELLOW}debian{Colour.NC}       - Enter Debian Trixie CLI")
    print(f"  {Colour.YELLOW}debian-gui{Colour.NC}   - Launch XFCE4 desktop (Termux-X11 APK required)")
    print()
    print(f"{Colour.BLUE}[i]{Colour.NC} Prerequisites:")
    print(f"    \u2022 Termux from F-Droid: https://f-droid.org/packages/com.termux/")
    print(f"    \u2022 Termux-X11 APK:      https://github.com/termux/termux-x11/releases")
    print()
    print(f"{Colour.YELLOW}[!]{Colour.NC} If 'debian' not found:  {Colour.GREEN}source ~/.bashrc{Colour.NC}")
    print()


# ── Main ────────────────────────────────────────────────────────────────
def main():
    state = State()

    print()
    print(f"{Colour.BLUE}{'╔' + '═' * 54 + '╗'}{Colour.NC}")
    print(f"{Colour.BLUE}║{'':>30} {'':<24}║{Colour.NC}")
    print(f"{Colour.BLUE}║{'   termux-debian-auto \u2014 Debian Trixie for Termux':^55}║{Colour.NC}")
    print(f"{Colour.BLUE}║{'':>30} {'':<24}║{Colour.NC}")
    print(f"{Colour.BLUE}║{'   github.com/highoncomputers/termux-debian-auto':^55}║{Colour.NC}")
    print(f"{Colour.BLUE}║{'':>30} {'':<24}║{Colour.NC}")
    print(f"{Colour.BLUE}{'╚' + '═' * 54 + '╝'}{Colour.NC}")
    print()
    print(f"{Colour.BLUE}[i]{Colour.NC} Log: {LOG_FILE}")
    print()

    log.info("Installation started")

    steps = [
        step_system_check,
        step_install_deps,
        step_install_trixie,
        step_configure_debian,
        step_configure_xfce4,
        step_configure_audio,
        step_create_launchers,
        step_verify,
        step_finalize,
    ]

    for step_fn in steps:
        try:
            step_fn(state)
        except (SystemExit, KeyboardInterrupt):
            raise
        except Exception as e:
            error(f"Step failed: {e}")
            log.exception("Step failed")
            print()
            warn("Re-run the same command to resume from this step:")
            print(f"  {Colour.GREEN}curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash{Colour.NC}")
            print()
            sys.exit(1)


if __name__ == "__main__":
    main()
PYEOF
