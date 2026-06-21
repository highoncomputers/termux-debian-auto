#!/data/data/com.termux/files/usr/bin/bash
# Smoke test for termux-debian-auto
# Verifies the installation is complete and commands exist

set -euo pipefail

PASS=0
FAIL=0

test_pass() {
    echo "[PASS] $1"
    ((PASS++))
}

test_fail() {
    echo "[FAIL] $1"
    ((FAIL++))
}

echo "=== termux-debian-auto Smoke Test ==="
echo

# Check launchers exist
echo "--- Checking launcher scripts ---"
if [[ -x "${PREFIX}/bin/debian" ]]; then
    test_pass "debian launcher exists"
else
    test_fail "debian launcher missing"
fi

if [[ -x "${PREFIX}/bin/debian-gui" ]]; then
    test_pass "debian-gui launcher exists"
else
    test_fail "debian-gui launcher missing"
fi

# Check proot-distro installation
echo "--- Checking proot-distro ---"
if command -v proot-distro &>/dev/null; then
    test_pass "proot-distro installed"
else
    test_fail "proot-distro missing"
fi

# Check Debian is installed
echo "--- Checking Debian installation ---"
if proot-distro list 2>/dev/null | grep -q "debian"; then
    test_pass "Debian proot-distro installed"
else
    test_fail "Debian proot-distro not found"
fi

# Check user exists in Debian
echo "--- Checking Debian user ---"
DEBIAN_USER="debian"
ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/debian"
if [[ -d "${ROOTFS}/home/${DEBIAN_USER}" ]]; then
    test_pass "Debian user '${DEBIAN_USER}' exists"
else
    test_fail "Debian user '${DEBIAN_USER}' not found"
fi

# Check XFCE4 is installed inside Debian
echo "--- Checking XFCE4 ---"
if [[ -f "${ROOTFS}/usr/bin/startxfce4" ]]; then
    test_pass "XFCE4 installed in Debian"
else
    test_fail "XFCE4 not found in Debian"
fi

# Check sudo config
echo "--- Checking sudo ---"
if [[ -f "${ROOTFS}/etc/sudoers" ]]; then
    test_pass "sudo is configured"
else
    test_fail "sudo not configured"
fi

# Check sound config
echo "--- Checking audio ---"
if [[ -f "${HOME}/.sound" ]]; then
    test_pass "PulseAudio startup script exists"
else
    test_fail "PulseAudio startup script missing"
fi

echo
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi