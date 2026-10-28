#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${TUNGUSKA_APP_PATH:-$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug/Tunguska.app' -maxdepth 6 -print -quit)}"
HELPER_SOURCE="${TUNGUSKA_HELPER_PATH:-$APP_PATH/Contents/Resources/TunguskaHelper}"
SINGBOX_SOURCE="${TUNGUSKA_SINGBOX_PATH:-$APP_PATH/Contents/Resources/sing-box}"
FRAMEWORK_SOURCE="${TUNGUSKA_CORE_FRAMEWORK_PATH:-$APP_PATH/Contents/Frameworks/TunguskaCore.framework}"

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found at $APP_PATH." >&2
    echo "Build the Tunguska scheme first, or set TUNGUSKA_APP_PATH." >&2
    exit 1
fi

if [ ! -f "$HELPER_SOURCE" ]; then
    echo "TunguskaHelper not found at $HELPER_SOURCE." >&2
    echo "Build the Tunguska scheme first, or set TUNGUSKA_HELPER_PATH." >&2
    exit 1
fi

if [ ! -f "$SINGBOX_SOURCE" ]; then
    echo "sing-box CLI not found at $SINGBOX_SOURCE." >&2
    echo "Run ./scripts/build-singbox-cli.sh first." >&2
    exit 1
fi

if [ ! -d "$FRAMEWORK_SOURCE" ]; then
    echo "TunguskaCore.framework not found at $FRAMEWORK_SOURCE." >&2
    echo "Build the Tunguska scheme first, or set TUNGUSKA_CORE_FRAMEWORK_PATH." >&2
    exit 1
fi

INSTALL_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/tunguska-install-helper.XXXXXX.sh")"
trap 'rm -f "$INSTALL_SCRIPT"' EXIT

cat > "$INSTALL_SCRIPT" <<EOF
#!/bin/bash
set -euo pipefail

APP_PATH='$APP_PATH'
HELPER_SOURCE='$HELPER_SOURCE'
SINGBOX_SOURCE='$SINGBOX_SOURCE'
FRAMEWORK_SOURCE='$FRAMEWORK_SOURCE'

/usr/bin/install -d -o root -g wheel -m 755 /Library/Tunguska /Library/Tunguska/runtime /Library/Tunguska/logs /Library/Tunguska/Frameworks
/usr/bin/install -o root -g wheel -m 755 "\$HELPER_SOURCE" /Library/Tunguska/TunguskaHelper
/usr/bin/install -o root -g wheel -m 755 "\$SINGBOX_SOURCE" /Library/Tunguska/sing-box
/usr/bin/ditto "\$FRAMEWORK_SOURCE" /Library/Tunguska/Frameworks/TunguskaCore.framework
/usr/sbin/chown -R root:wheel /Library/Tunguska/Frameworks/TunguskaCore.framework

/usr/bin/xattr -dr com.apple.quarantine /Library/Tunguska/TunguskaHelper 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine /Library/Tunguska/sing-box 2>/dev/null || true
/usr/bin/codesign --force --sign - /Library/Tunguska/Frameworks/TunguskaCore.framework 2>/dev/null || true
/usr/bin/codesign --force --sign - /Library/Tunguska/TunguskaHelper 2>/dev/null || true
/usr/bin/codesign --force --sign - /Library/Tunguska/sing-box 2>/dev/null || true

cat > /Library/LaunchDaemons/dev.tunguska.macos.helper.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.tunguska.macos.helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/Tunguska/TunguskaHelper</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>WorkingDirectory</key>
    <string>/Library/Tunguska</string>
    <key>StandardOutPath</key>
    <string>/Library/Tunguska/logs/helper.out.log</string>
    <key>StandardErrorPath</key>
    <string>/Library/Tunguska/logs/helper.err.log</string>
</dict>
</plist>
PLIST

/usr/sbin/chown root:wheel /Library/LaunchDaemons/dev.tunguska.macos.helper.plist
/bin/chmod 644 /Library/LaunchDaemons/dev.tunguska.macos.helper.plist

/bin/launchctl unload /Library/LaunchDaemons/dev.tunguska.macos.helper.plist 2>/dev/null || true
/bin/launchctl load -w /Library/LaunchDaemons/dev.tunguska.macos.helper.plist
rm -f /var/run/tunguska-helper.sock

echo "Installed Tunguska helper and sing-box CLI."
EOF

chmod 755 "$INSTALL_SCRIPT"

echo "Installing the privileged Tunguska helper. macOS will ask for an administrator password."
/usr/bin/osascript -e "do shell script \"/bin/bash '$INSTALL_SCRIPT'\" with administrator privileges"
