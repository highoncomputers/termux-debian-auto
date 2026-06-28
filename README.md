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

Installs Debian **Trixie** (Debian 13/testing) directly via Docker/OCI image — no Bookworm involved at all:

1. ✅ Checks system compatibility
2. ✅ Installs Termux packages: `proot-distro`, `termux-x11-nightly`, `pulseaudio`
3. ✅ Pulls `debian:trixie` Docker image via proot-distro v5
4. ✅ Configures user `debian` with passwordless sudo
5. ✅ Installs XFCE4 desktop, Firefox ESR, audio
6. ✅ Creates `debian` and `debian-gui` launcher commands
7. ✅ Verifies everything works — self-healing re-runs

## Usage

### CLI Environment

```bash
debian
```

Enters the Debian Trixie environment. Type `exit` to return to Termux.

### GUI Desktop

```bash
debian-gui
```

Launches XFCE4 via Termux X11:
- Starts Termux X11 on display `:0`
- Logs into Debian Trixie with shared `$TMPDIR`
- Launches `startxfce4` via dbus

## Self-Healing

If the installation is interrupted (network drop, battery dies), just re-run the same command:

```bash
curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash
```

It detects completed steps and skips them automatically.

## FAQ

### Do I need root?
No. Everything runs in user-space via proot.

### Why Trixie and not Bookworm?
Debian Trixie (testing) has newer packages. The installer pulls `debian:trixie` directly — no Bookworm involved at any stage.

### How do I install additional packages?
Inside the Debian CLI:
```bash
sudo apt update
sudo apt install <package>
```

### How does this differ from the old version?
This uses **proot-distro v5** which pulls Docker/OCI images directly. The old version installed Bookworm via tarball then dist-upgraded. This version installs Trixie from the start.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
