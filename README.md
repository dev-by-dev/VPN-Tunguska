# Tunguska for macOS

A native Apple Silicon VPN client for VLESS + REALITY, built with SwiftUI and NetworkExtension.

The product mirrors Tunguska's safety model rather than its Android implementation: staged profile import, explicit routing, encrypted local state, a native sing-box runtime, and no unauthenticated local proxy or management API.

## Status

Early development. The platform-independent profile/import/routing core is implemented and validated. The SwiftUI instrument-panel app, Keychain-backed profile store, NetworkExtension controller, and packet-tunnel provider with the pinned libbox engine are implemented and compile for arm64. A real connection still requires a Team-signed NetworkExtension host with the NetworkExtension entitlement; an unsigned or ad-hoc local build cannot start the tunnel. The UI must never claim that an unavailable runtime is connected.

## Requirements

- Apple Silicon Mac
- macOS 14 Sonoma or newer
- Xcode 16 or newer for the app and tunnel targets
- Go and XcodeGen for reproducible project/runtime generation

The core package and its tests can also be built with Swift Command Line Tools.

## Project layout

- `Sources/TunguskaCore`: platform-independent profile, import, validation, and routing logic
- `Sources/Tunguska`: SwiftUI application, AppModel, Keychain profile store, and tunnel controller
- `Sources/TunguskaTunnel`: NetworkExtension packet-tunnel provider with libbox setup, platform interface, TUN settings, and fail-closed startup
- `Tests/TunguskaCoreTests`: core unit tests
- `docs`: product and architecture decisions
- `scripts`: reproducible build helpers

## Local validation

```bash
./scripts/validate-local.sh
```

Equivalent individual commands are `swift build --target Tunguska`, `swift build --target TunguskaTunnel`, `swift test`, and `swift run TunguskaCoreCheck`.

## Native runtime build

After installing a full Xcode release and selecting it with `xcode-select`, build the pinned macOS libbox runtime:

```bash
./scripts/build-libbox-macos.sh
```

The script uses the sibling pinned sing-box checkout by default and stages `Vendor/Libbox.xcframework`. It defaults to the Go 1.25 toolchain required by the pinned jsonv2 dependency; override it with `TUNGUSKA_GOTOOLCHAIN` when needed. Override the source or output with `TUNGUSKA_SINGBOX_SRC` or `TUNGUSKA_LIBBOX_OUTPUT` when needed. The generated framework is local build output and must not be committed.

After installing Xcode, generate the project:

```bash
./scripts/generate-xcode-project.sh
open Tunguska.xcodeproj
```

`Config/Signing.xcconfig` is intentionally ignored. Do not commit profile links, REALITY secrets, signing identities, or runtime credentials.

## Signing

The app and tunnel share a Keychain access group so the provider can resolve the selected profile without copying secrets into `NETunnelProviderManager`. Team-signed builds use the `keychain-access-groups` and NetworkExtension entitlements in `Config/`.

Local ad-hoc signing is available for UI and Keychain smoke tests:

```bash
APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug/Tunguska.app' -maxdepth 6 -print -quit)"
TUNGUSKA_APP_PATH="$APP_PATH" ./scripts/sign-local-adhoc.sh
open -n -W "$APP_PATH" --args --keychain-self-test
```

The ad-hoc script removes restricted entitlements that AMFI rejects. Consequently, local ad-hoc builds can run the app and exercise the legacy Keychain fallback, but they cannot start the NetworkExtension. A real tunnel smoke test requires a development team and proper provisioning.

## Security principles

- Validate and preview imports before persistence.
- Keep profile secrets in Keychain, not UserDefaults or logs.
- Export backups only as authenticated AES-256-GCM ciphertext with a PBKDF2-HMAC-SHA256 passphrase key; never persist the passphrase.
- Diagnostics are redacted by construction: no profile IDs, endpoints, UUIDs, REALITY keys, short IDs, DNS endpoints, or routing domains.
- Do not auto-connect after import.
- Keep loopback traffic local.
- No open localhost proxy, debug listener, or management API.
- Fail closed when the runtime or its configuration is invalid.
- A connected visual state must be backed by a live NetworkExtension session.
