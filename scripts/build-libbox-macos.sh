#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SINGBOX_SRC="${TUNGUSKA_SINGBOX_SRC:-$ROOT_DIR/../tunguska/.tmp/sing-box-src}"
OUTPUT_DIR="${TUNGUSKA_LIBBOX_OUTPUT:-$ROOT_DIR/Vendor/Libbox.xcframework}"

if ! command -v go >/dev/null 2>&1; then
  echo "error: Go is required to build Libbox" >&2
  exit 1
fi

export PATH="$(go env GOPATH)/bin:$PATH"
export GOTOOLCHAIN="${TUNGUSKA_GOTOOLCHAIN:-go1.25.14}"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: a full Xcode installation is required to build the macOS xcframework" >&2
  echo "Install Xcode, then select it with:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

for tool in gomobile gobind; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool was not found in PATH; expected under $(go env GOPATH)/bin" >&2
    exit 1
  fi
done

if [[ ! -f "$SINGBOX_SRC/cmd/internal/build_libbox/main.go" ]]; then
  echo "error: pinned sing-box source was not found at $SINGBOX_SRC" >&2
  echo "Set TUNGUSKA_SINGBOX_SRC to the checkout used for the pinned revision." >&2
  exit 1
fi

gomobile init

cd "$SINGBOX_SRC"
go run ./cmd/internal/build_libbox -target apple -platform macos

SOURCE_FRAMEWORK="$SINGBOX_SRC/Libbox.xcframework"
if [[ ! -d "$SOURCE_FRAMEWORK" ]]; then
  SIBLING_FRAMEWORK="$(cd "$SINGBOX_SRC/.." && pwd)/sing-box-for-apple/Libbox.xcframework"
  if [[ -d "$SIBLING_FRAMEWORK" ]]; then
    SOURCE_FRAMEWORK="$SIBLING_FRAMEWORK"
  fi
fi

if [[ ! -d "$SOURCE_FRAMEWORK" ]]; then
  echo "error: build completed, but Libbox.xcframework was not found" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_DIR")"
rm -rf "$OUTPUT_DIR"
cp -R "$SOURCE_FRAMEWORK" "$OUTPUT_DIR"

printf 'Built %s\n' "$OUTPUT_DIR"
