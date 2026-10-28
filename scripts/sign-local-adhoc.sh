#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

APP_PATH="${TUNGUSKA_APP_PATH:-$HOME/Library/Developer/Xcode/DerivedData/Tunguska-gwyvaexzbwfjpdefwvclewwxmoll/Build/Products/Debug/Tunguska.app}"

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found at $APP_PATH." >&2
    echo "Build the Tunguska scheme first, or set TUNGUSKA_APP_PATH." >&2
    exit 1
fi

if ! command -v codesign >/dev/null 2>&1; then
    echo "codesign is required." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tunguska-sign.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# An ad-hoc signature has no Team ID and cannot carry restricted entitlements such as
# keychain-access-groups or the NetworkExtension entitlement. AMFI rejects such a process
# before launchd can start it. Strip only those entitlements for this local/development
# signature; a real Team-signed build keeps the source entitlements unchanged.
cp Config/Tunguska.entitlements "$WORK_DIR/Tunguska.entitlements"
cp Config/TunguskaTunnel.entitlements "$WORK_DIR/TunguskaTunnel.entitlements"

for entitlement_file in "$WORK_DIR/Tunguska.entitlements" "$WORK_DIR/TunguskaTunnel.entitlements"; do
    plutil -remove keychain-access-groups "$entitlement_file" >/dev/null 2>&1 || true
    plutil -remove com.apple.developer.networking.networkextension "$entitlement_file" >/dev/null 2>&1 || true
done

HELPER_PATH="${TUNGUSKA_HELPER_PATH:-$(dirname "$APP_PATH")/TunguskaHelper}"

codesign --force --sign - "$APP_PATH/Contents/Frameworks/TunguskaCore.framework"
if [ -d "$APP_PATH/Contents/PlugIns/TunguskaTunnel.appex" ]; then
    codesign --force --sign - --entitlements "$WORK_DIR/TunguskaTunnel.entitlements" \
        "$APP_PATH/Contents/PlugIns/TunguskaTunnel.appex"
fi
if [ -f "$HELPER_PATH" ]; then
    codesign --force --sign - "$HELPER_PATH"
fi
codesign --force --sign - --entitlements "$WORK_DIR/Tunguska.entitlements" "$APP_PATH"

echo "Signed $APP_PATH with local ad-hoc entitlements."
if [ -f "$HELPER_PATH" ]; then
    echo "Signed $HELPER_PATH ad-hoc."
fi
