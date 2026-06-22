<div align="center">
  <h1>termux-debian-auto</h1>
  <p><strong>One-command Debian + XFCE4 desktop for Termux — Zero configuration, fully automated.</strong></p>
  <p>
    <a href="https://github.com/highoncomputers/termux-debian-auto/blob/main/LICENSE">
      <img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License: GPL-3.0">
    </a>
    <a href="https://github.com/highoncomputers/termux-debian-auto/releases">
      <img src="https://img.shields.io/github/v/release/highoncomputers/termux-debian-auto" alt="Release">
    </a>
    <a href="#">
      <img src="https://img.shields.io/badge/platform-android-lightgrey?logo=android" alt="Platform: Android">
    </a>
    <a href="#">
      <img src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash" alt="Shell: Bash">
    </a>
    <a href="#">
      <img src="https://img.shields.io/badge/debian-bookworm-A81D33?logo=debian" alt="Debian Bookworm">
    </a>
    <a href="#">
      <img src="https://img.shields.io/badge/desktop-XFCE4-2288DD?logo=xfce" alt="Desktop: XFCE4">
    </a>
  </p>
</div>

---

## ✨ Features

- **One-line installation** — Paste a single command, everything installs automatically
- **`debian`** — Type `debian` to enter the Debian CLI environment instantly
- **`debian-gui`** — Type `debian-gui` to launch a full XFCE4 desktop via Termux X11
- **Auto-cleanup** — `debian-gui` kills any existing X11/proot sessions before starting fresh
- **Hardware acceleration** — VirGL/virpipe for GPU rendering
- **Audio support** — PulseAudio over TCP
- **No root required** — Runs entirely in user-space via [proot-distro](https://github.com/termux/proot-distro)
- **Web browser** — Firefox ESR included

## 📋 Prerequisites

| Requirement | Details |
|-------------|---------|
| **Termux** | Install from [F-Droid](https://f-droid.org/packages/com.termux/) (recommended) or GitHub |
| **Termux-X11 APK** | Download from the [releases page](https://github.com/termux/termux-x11/releases) |
| **Android** | Version 7.0+, ARM64 (aarch64) recommended |
| **Storage** | 4 GB+ free space |
| **RAM** | 2 GB+ recommended |

> **Important**: Install Termux from F-Droid, not Google Play. The Play Store version is outdated.

## 🚀 Quick Start

Open Termux and run:

```bash
curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash
```

The installer will:
1. Check system compatibility
2. Install required packages (proot-distro, x11, pulseaudio, virgl, etc.)
3. Install and configure Debian proot-distro
4. Set up XFCE4 desktop with theme and panel
5. Configure PulseAudio for audio forwarding
6. Enable hardware acceleration (virpipe)
7. Create `debian` and `debian-gui` launcher commands

## 🎮 Usage

### CLI Environment
```bash
debian
```
Enters the Debian proot environment as user `debian`. Type `exit` to return to Termux.

### GUI Desktop
```bash
debian-gui
```
Launches the full XFCE4 desktop via Termux X11. This command:
1. Kills any existing termux-x11, proot-distro, pulseaudio, and virgl sessions
2. Starts fresh PulseAudio with TCP audio forwarding
3. Launches Termux X11 on display `:1`
4. Starts VirGL for hardware acceleration
5. Opens the XFCE4 desktop session

> The `debian-gui` command **always starts fresh** — no orphaned processes or stale sessions.

## 📦 What Gets Installed

### Termux Packages
| Package | Purpose |
|---------|---------|
| `proot-distro` | Container management |
| `termux-x11-nightly` | X11 server |
| `pulseaudio` | Audio server |
| `virglrenderer-android` | GPU acceleration |
| `x11-repo` / `tur-repo` | Additional repositories |
| `xfce4` / `xfce4-terminal` | Desktop environment |

### Debian Packages (inside proot)
| Package | Purpose |
|---------|---------|
| `sudo` | Privilege escalation |
| `xfce4` / `xfce4-goodies` | Desktop environment |
| `dbus-x11` | D-Bus for X11 |
| `firefox-esr` | Web browser |

## 🔧 Configuration

### User
- **Username**: `debian` (fixed, no password)
- **Sudo**: NOPASSWD (passwordless sudo)
- **Shell**: `/bin/bash`

### Display
- **Display**: `:1` (avoids conflicts with native Termux X11 on `:0`)
- **Shared-tmp**: Enabled (access Termux packages from inside Debian)

### Audio
- PulseAudio runs in TCP mode on `127.0.0.1`
- Auto-started via `~/.sound` script

### Graphics
- **Driver**: `virpipe` (VirGL)
- **Override**: `MESA_GL_VERSION_OVERRIDE=4.0`

## 🗂️ Project Structure

```
termux-debian-auto/
├── install.sh              # One-liner entry point
├── scripts/
│   ├── 01-system-check.sh  # Architecture, storage, RAM validation
│   ├── 02-install-deps.sh  # Termux packages installation
│   ├── 03-install-debian.sh# proot-distro Debian + user setup
│   ├── 04-setup-gui.sh     # XFCE4 config (panel, theme, terminal)
│   ├── 05-setup-audio.sh   # PulseAudio TCP configuration
│   ├── 06-setup-accel.sh   # VirGL hardware acceleration
│   ├── 07-create-launchers.sh # debian/debian-gui commands
│   └── 08-finalize.sh      # Termux settings + success message
├── bin/
│   ├── debian              # CLI launcher script
│   └── debian-gui          # GUI launcher script
├── config/
│   ├── termux.properties   # Termux configuration template
│   └── pulseaudio/         # PulseAudio configuration
├── tests/
│   └── smoke-test.sh       # Installation validation
└── .github/workflows/
    └── release.yml         # GitHub Release automation
```

## ❓ FAQ

### Do I need root?
No. Everything runs in user-space using proot.

### Why display `:1` instead of `:0`?
Display `:0` is typically used by native Termux X11 sessions. Using `:1` prevents conflicts when both are running.

### How do I install additional packages?
Inside the Debian CLI or terminal:
```bash
sudo apt update
sudo apt install <package>
```

### How do I update?
Run the installer again — it's idempotent:
```bash
curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash
```

## 📄 License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- [proot-distro](https://github.com/termux/proot-distro) — Container management
- [Termux](https://termux.com) — Terminal emulator
- [Termux-X11](https://github.com/termux/termux-x11) — X11 server for Android
- [proot-distro-scripts](https://github.com/01101010110/proot-distro-scripts) — Community scripts (inspiration)
- [Termux-XFCE](https://github.com/phoenixbyrd/Termux_XFCE) — XFCE setup scripts (inspiration)