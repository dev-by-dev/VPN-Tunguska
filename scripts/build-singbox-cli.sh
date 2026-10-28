#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="${TUNGUSKA_SINGBOX_SRC:-$PWD/../tunguska/.tmp/sing-box-src}"
OUT="${TUNGUSKA_SINGBOX_CLI_OUTPUT:-$PWD/Resources/Runtime/sing-box}"
GOTOOLCHAIN="${TUNGUSKA_GOTOOLCHAIN:-go1.25.14}"

if ! command -v go >/dev/null 2>&1; then
    echo "Go is required to build the sing-box CLI runtime." >&2
    exit 1
fi

if [ ! -d "$SRC" ]; then
    echo "sing-box source checkout not found at $SRC." >&2
    echo "Set TUNGUSKA_SINGBOX_SRC to the pinned sing-box checkout." >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo "Building sing-box CLI from $SRC"
(
    cd "$SRC"
    # macOS needs CGO for sing-box's local DNS resolver implementation.
    GOTOOLCHAIN="$GOTOOLCHAIN" \
        go build -trimpath -tags with_utls -o "$OUT" ./cmd/sing-box
)

chmod 755 "$OUT"
echo "Built $OUT"
