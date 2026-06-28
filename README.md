# termux-debian-auto

**One-command Debian Trixie + XFCE4 desktop for Termux — Zero configuration, fully automated.**

## Quick Start

Open Termux and run:

```bash
curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Termux** | Install from [F-Droid](https://f-droid.org/packages/com.termux/) (recommended) or GitHub |
| **Termux-X11 APK** | Download from the [releases page](https://github.com/termux/termux-x11/releases) and install as a regular Android app |
| **Android** | Version 7.0+, ARM64 (aarch64) recommended |
| **Storage** | 4 GB+ free space |
| **RAM** | 2 GB+ recommended |

> Install Termux from **F-Droid**, not Google Play. The Play Store version is outdated.

## What It Does

The installer automatically:

1. Checks system compatibility
2. Installs required Termux packages (`proot-distro`, `termux-x11-nightly`, `pulseaudio`, `virglrenderer-android`, `xfce4`, etc.)
3. Installs Debian via `proot-distro` and **upgrades it to Trixie** (Debian 13/testing)
4. Creates user `debian` with passwordless sudo
5. Configures XFCE4 desktop (panel, terminal, theme)
6. Sets up PulseAudio for audio forwarding
7. Enables VirGL hardware acceleration
8. Creates `debian` and `debian-gui` launcher commands

## Usage

### CLI Environment

```bash
debian
```

Enters the Debian Trixie proot environment as user `debian`. Type `exit` to return to Termux.

### GUI Desktop

```bash
debian-gui
```

Launches a full XFCE4 desktop via Termux X11. This command:

1. Kills any existing termux-x11 / proot / pulseaudio / virgl sessions
2. Starts fresh PulseAudio with TCP audio forwarding
3. Launches Termux X11 on display `:1`
4. Starts VirGL for hardware acceleration
5. Opens the XFCE4 desktop session

> The `debian-gui` command always starts fresh — no orphaned processes.

## What Gets Installed

### Termux Packages

- `proot-distro` — Container management
- `termux-x11-nightly` — X11 server
- `pulseaudio` — Audio server
- `virglrenderer-android` — GPU acceleration
- `xfce4`, `xfce4-terminal` — Desktop environment

### Debian Trixie Packages

- `sudo` — Privilege escalation (NOPASSWD for user `debian`)
- `xfce4`, `xfce4-goodies` — Desktop environment
- `dbus-x11` — D-Bus for X11
- `firefox-esr` — Web browser
- `pavucontrol-qt` — Audio control

## Commands

| Command | Description |
|---------|-------------|
| `debian` | Enter Debian Trixie CLI |
| `debian-gui` | Launch XFCE4 desktop |

## Configuration

- **Username**: `debian` (no password)
- **Sudo**: NOPASSWD (passwordless)
- **Display**: `:1` (avoids conflicts with native Termux X11 on `:0`)
- **Shared-tmp**: Enabled (access Termux packages from inside Debian)
- **Audio**: PulseAudio TCP mode on `127.0.0.1`
- **Graphics**: VirGL via `virpipe` driver

## Updating

Run the installer again — it's idempotent:

```bash
curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash
```

## FAQ

### Do I need root?
No. Everything runs in user-space using proot.

### Why display `:1` instead of `:0`?
Display `:0` is used by native Termux X11 sessions. Using `:1` prevents conflicts.

### How do I install additional packages?
Inside the Debian CLI or terminal:
```bash
sudo apt update
sudo apt install <package>
```

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
