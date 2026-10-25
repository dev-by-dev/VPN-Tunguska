#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

if xcodebuild -version >/dev/null 2>&1; then
    echo "Generated Tunguska.xcodeproj. Open it in Xcode to sign and build the app/extension."
else
    echo "Generated Tunguska.xcodeproj, but full Xcode/xcodebuild was not found."
    echo "Install Xcode before building the NetworkExtension app bundle."
fi
