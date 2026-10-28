#!/usr/bin/env bash
set -euo pipefail

UNINSTALL_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/tunguska-uninstall-helper.XXXXXX.sh")"
trap 'rm -f "$UNINSTALL_SCRIPT"' EXIT

cat > "$UNINSTALL_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail

PLIST=/Library/LaunchDaemons/dev.tunguska.macos.helper.plist

/bin/launchctl unload "$PLIST" 2>/dev/null || true
/usr/bin/pkill -f /Library/Tunguska/TunguskaHelper 2>/dev/null || true
rm -f "$PLIST"
rm -rf /Library/Tunguska
rm -f /var/run/tunguska-helper.sock

echo "Removed the Tunguska privileged helper and runtime."
EOF

chmod 755 "$UNINSTALL_SCRIPT"

echo "Removing the privileged Tunguska helper. macOS will ask for an administrator password."
/usr/bin/osascript -e "do shell script \"/bin/bash '$UNINSTALL_SCRIPT'\" with administrator privileges"
