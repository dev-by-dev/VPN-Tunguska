# Tunguska for macOS

A native Apple Silicon VPN client for VLESS + REALITY, built with SwiftUI and a Clash-Verge-style privileged helper. The app talks to a root `TunguskaHelper` LaunchDaemon; the helper starts a pinned `sing-box` CLI, creates the TUN interface, and owns routes/DNS.

The product mirrors Tunguska's safety model rather than its Android implementation: staged profile import, explicit routing, encrypted local state, a native sing-box runtime, and no unauthenticated local proxy or management API.

## Status

Early development. The platform-independent profile/import/routing core, SwiftUI instrument-panel app, Keychain-backed profile store, encrypted backup, redacted diagnostics, privileged-helper protocol, and helper daemon are implemented and compile for arm64. The current tunnel path is the Clash-Verge-style helper service, not NetworkExtension.

A live tunnel requires installing the privileged helper once with an administrator password. Unsigned/ad-hoc local builds can run this path, but macOS may show Gatekeeper warnings; do not install or run an unsigned privileged helper from an untrusted source.

## Requirements

- Apple Silicon Mac
- macOS 14 Sonoma or newer
- Xcode 16 or newer for the app and helper targets
- Go and XcodeGen for reproducible project/runtime generation

The core package and its tests can also be built with Swift Command Line Tools.

## Project layout

- `Sources/TunguskaCore`: platform-independent profile, import, validation, routing, backup, diagnostics, and helper protocol logic
- `Sources/Tunguska`: SwiftUI application, AppModel, Keychain profile store, tunnel controller, and local helper client
- `Sources/TunguskaHelper`: privileged LaunchDaemon executable that validates requests, starts/stops `sing-box`, and observes the TUN interface
- `Sources/TunguskaTunnel`: legacy NetworkExtension packet-tunnel provider with libbox setup; retained as a Team-signed alternative, not used by the helper path
- `Tests/TunguskaCoreTests`: core unit tests
- `docs`: product and architecture decisions
- `scripts`: reproducible build, signing, install, and uninstall helpers

## Local validation

```bash
./scripts/validate-local.sh
```

Equivalent individual commands are `swift build --target Tunguska`, `swift build --target TunguskaHelper`, `swift test`, and `swift run TunguskaCoreCheck`.

## Runtime build

Build the pinned macOS sing-box CLI used by the privileged helper:

```bash
./scripts/build-singbox-cli.sh
```

The script uses the sibling pinned sing-box checkout by default and stages `Resources/Runtime/sing-box`. It defaults to the Go 1.25 toolchain required by the pinned jsonv2 dependency; override it with `TUNGUSKA_GOTOOLCHAIN` when needed. Override the source or output with `TUNGUSKA_SINGBOX_SRC` or `TUNGUSKA_SINGBOX_CLI_OUTPUT` when needed. The generated runtime binary is local build output and must not be committed.

Build the legacy libbox NetworkExtension runtime only if you are exercising the retained `TunguskaTunnel` target:

```bash
./scripts/build-libbox-macos.sh
```

After installing Xcode, generate the project:

```bash
./scripts/generate-xcode-project.sh
open Tunguska.xcodeproj
```

`Config/Signing.xcconfig` is intentionally ignored. Do not commit profile links, REALITY secrets, signing identities, runtime credentials, or local helper payloads.

## Local helper install

Build the app and helper, build the sing-box CLI, then install the privileged service:

```bash
./scripts/build-singbox-cli.sh
./scripts/generate-xcode-project.sh
xcodebuild -project Tunguska.xcodeproj -scheme Tunguska -configuration Debug \
  -destination 'generic/platform=macOS' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO -allowProvisioningUpdates
./scripts/sign-local-adhoc.sh
./scripts/install-helper.sh
```

`install-helper.sh` asks macOS for an administrator password, copies `TunguskaHelper`, `TunguskaCore.framework`, and `sing-box` into `/Library/Tunguska`, and registers `/Library/LaunchDaemons/dev.tunguska.macos.helper.plist`.

To remove the service and runtime:

```bash
./scripts/uninstall-helper.sh
```

## Signing

The Clash-Verge-style path does not need the restricted NetworkExtension entitlement. The helper is a LaunchDaemon installed under `/Library/Tunguska`; the app is non-sandboxed and communicates with it over a local Unix socket after checking the caller process.

Team-signed builds may additionally harden helper client authentication with code-signature requirements. Local ad-hoc builds can run the app/helper for development, but unsigned privileged helpers should not be distributed broadly. For public GitHub releases, prefer signed/notarized helper binaries or source-only distribution.

## Security principles

- Validate and preview imports before persistence.
- Keep profile secrets in Keychain, not UserDefaults or logs.
- Export backups only as authenticated AES-256-GCM ciphertext with a PBKDF2-HMAC-SHA256 passphrase key; never persist the passphrase.
- Diagnostics are redacted by construction: no profile IDs, endpoints, UUIDs, REALITY keys, short IDs, DNS endpoints, or routing domains.
- Do not auto-connect after import.
- Keep loopback traffic local.
- No open localhost proxy, debug listener, or management API.
- Fail closed when the runtime or its configuration is invalid.
- A connected visual state must be backed by a live TUN interface observed from the privileged helper.
- The helper accepts only a narrow Tunguska-shaped sing-box document; it must not become a generic arbitrary-command root service.
