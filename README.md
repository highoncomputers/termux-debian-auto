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
| **Android** | Version 7.0+, ARM64 recommended |
| **Storage** | 4 GB+ free space |

> Install Termux from **F-Droid**, not Google Play. The Play Store version is outdated.

## What It Does

1. ✅ Installs **Python 3** (first bootstrapper)
2. ✅ Installs Termux packages: `proot-distro`, `termux-x11-nightly`, `pulseaudio`
3. ✅ Pulls `debian:trixie` Docker image directly via proot-distro v5 — **no Bookworm involved**
4. ✅ Creates user `debian` with passwordless sudo
5. ✅ Installs XFCE4 desktop, Firefox ESR, PulseAudio
6. ✅ Creates `debian` and `debian-gui` launcher commands in `$PREFIX/bin`
7. ✅ Verifies everything works and adds PATH fallback if needed

## Usage

```bash
debian          # Enter Debian Trixie CLI
debian-gui      # Launch XFCE4 desktop (requires Termux-X11 APK)
```

## Self-Healing

If installation is interrupted, just re-run the same command — it skips completed steps automatically using `~/.termux-debian-auto/state.json`.

## Why Python?

The installer uses Python for reliable error handling, clean subprocess management (no shell escaping issues), JSON state tracking, and proper logging. The bash bootstrap simply installs Python 3 then hands off to the Python engine.

## FAQ

**Do I need root?** No. Everything runs in user-space via proot.

**Why Trixie?** Debian Trixie (testing) has newer packages. Pulled directly from `debian:trixie` Docker image — no Bookworm stage.

**Install more packages?** Inside the CLI: `sudo apt install <package>`

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
