# termux-debian-auto

**Turn Termux into a full Debian Trixie desktop — one command, zero config, no root.**

![Platform](https://img.shields.io/badge/platform-Android_7%2B-brightgreen)
![License](https://img.shields.io/badge/license-GPLv3-blue)

---

## Features

- **One-command installation** — run a single `curl | bash` and walk away
- **Full Debian Trixie** — latest packages, not stale Bookworm
- **XFCE4 desktop** — lightweight, fast, familiar
- **Auto-launch Termux-X11** — run `debian-gui` and the app opens automatically
- **PulseAudio** — sound out of the box
- **Firefox ESR** — web browser included
- **Self-healing** — interrupted? Re-run. It skips completed steps.
- **No root required** — everything runs user-space via proot

---

## How It Works

```
Termux (Android)
  └─ proot-distro (user-space chroot)
       └─ Debian Trixie
            ├─ CLI: debian
            └─ GUI: debian-gui → termux-x11 + XFCE4
```

No kernel modifications, no system partitions, no bootloaders. Just a proot container running a full Debian environment with X11 forwarding to the Termux-X11 Android app.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Termux** | Install from [F-Droid](https://f-droid.org/packages/com.termux/) only — the Play Store version is outdated |
| **Termux-X11 APK** | Download from the [releases page](https://github.com/termux/termux-x11/releases) and install as a normal Android app |
| **Android** | Version 7.0+, ARM64 recommended |
| **Storage** | 4 GB+ free space |

---

## Installation

Open Termux and run **one command**:

```bash
curl -sL https://raw.githubusercontent.com/highoncomputers/termux-debian-auto/main/install.sh | bash
```

That's it. The installer does everything automatically in 9 steps:

| Step | What Happens |
|------|-------------|
| 1 | Checks architecture and available storage |
| 2 | Installs Termux packages: proot-distro, termux-x11, pulseaudio, wget |
| 3 | Creates `debian` and `debian-gui` launcher commands |
| 4 | Downloads Debian (tarball) and upgrades it to Trixie |
| 5 | Installs XFCE4, Firefox ESR, PulseAudio, sudo, and more |
| 6 | Configures XFCE4 theme, terminal, and desktop settings |
| 7 | Configures PulseAudio for audio forwarding |
| 8 | Verifies the installation |
| 9 | Prints completion summary |

**Interrupted?** Just run the same command again. Completed steps are skipped automatically. No cleanup needed.

---

## Usage

### CLI Mode

```bash
debian
```

Opens a root shell inside Debian Trixie. Use `sudo apt install <package>` to add software.

### GUI Mode (Desktop)

```bash
debian-gui
```

This single command does everything automatically:

1. Starts the X11 server in the background
2. Opens the Termux-X11 Android app (no manual tapping needed)
3. Waits 3 seconds for initialization
4. Logs into Debian Trixie
5. Launches the XFCE4 desktop with PulseAudio and display forwarding

**Pro tip:** swipe from the left edge of the Termux-X11 screen to see the full desktop with panels and window manager.

---

## Why This? (Comparison)

| Aspect | termux-debian-auto | Manual proot-distro | UserLAnd | Andronix |
|--------|-------------------|-------------------|----------|----------|
| Setup time | ~5 min (automated) | 20-30 min (manual) | ~10 min | ~10 min |
| Desktop quality | Full XFCE4 | You configure it | Laggy | Requires subscription |
| Audio | PulseAudio included | Manual setup | Limited | Limited |
| Auto X11 launch | ✅ | ❌ | ❌ | ❌ |
| Self-healing | ✅ | ❌ | ❌ | ❌ |
| Cost | Free (GPL-3.0) | Free | Free tier limited | Paid mods |
| Debian version | Trixie (testing) | Bookworm (stable) | Bookworm | Varies |

---

## FAQ

**Do I need root?** No. Everything runs in user-space via proot.

**Why Trixie instead of Bookworm?** Debian Trixie (testing, will become stable) has significantly newer packages — newer kernels, browsers, development tools, and libraries.

**Can I install more packages?** Yes. Inside the CLI: `sudo apt install <package>`. Or from the GUI: open a terminal and run the same command.

**Is re-running safe?** Yes. State markers in `~/.termux-debian-auto/` track each completed step. Re-running only executes unfinished steps.

**Does audio work?** Yes. PulseAudio is configured to forward audio from the proot to your Android device.

**Can I access Android files?** Yes. Inside the proot, your Termux home is accessible and Android storage can be accessed via `/sdcard`.

**Why not Docker?** Docker requires root and a custom kernel — neither is available on stock Android. proot provides the same isolation without those requirements.

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).