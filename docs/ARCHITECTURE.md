# Architecture

## Boundaries

```text
SwiftUI app / MenuBarExtra
        │
        ▼
@MainActor AppModel
        │
        ├── ProfileImportParser ── TunguskaCore
        ├── RoutePreviewEngine ─── TunguskaCore
        ├── ProfileKeychainStore ── SecItem generic-password items
        └── TunnelController ────── HelperClient
                                      │
                                      ▼
                            Unix socket /var/run/tunguska-helper.sock
                                      │
        ┌─────────────────────────────┘
        ▼
TunguskaHelper LaunchDaemon
        │
        ├── validates HelperRequest / Tunguska-shaped sing-box config
        ├── writes /Library/Tunguska/runtime/active-config.json (0600)
        └── starts/stops /Library/Tunguska/sing-box
                                      │
                                      ▼
                             TUN + routes + DNS
                                      │
                               VLESS + REALITY
```

`TunguskaCore` has no SwiftUI, NetworkExtension, or root-helper dependency. This keeps import, routing, diagnostics, backup, configuration generation, and helper protocol semantics testable without a privileged process.

`Sources/TunguskaHelper` is deliberately narrow. It accepts only `status`, `start`, and `stop`; `start` accepts only a Tunguska-shaped sing-box JSON document containing a TUN inbound plus VLESS/direct/block outbounds and a route section. It does not expose arbitrary shell execution, general process spawning, file editing, or a management API.

The retained `Sources/TunguskaTunnel` NetworkExtension target remains as a Team-signed alternative. The helper path does not embed or require it.

## State ownership

- `AppModel` owns presentation state on the main actor.
- `TunnelController` owns desired start/stop intent and maps helper-observed state into UI state.
- `TunguskaHelper` owns the root `sing-box` process, runtime config path, log files, and observed TUN interface.
- Desired user state and observed runtime state are separate values.
- UI shows `Connected` only when the helper reports a running `sing-box` process and a non-nil TUN interface.

## Import and persistence

Import is staged: input → validation → normalized preview → explicit confirmation → Keychain replacement. Import never starts VPN automatically. The UI masks stored UUID/REALITY material.

The app resolves the selected profile from `ProfileKeychainStore`, builds the sing-box configuration with `SingBoxConfigurationBuilder`, and sends that sealed runtime document to the helper. The helper receives the runtime config over the local authenticated socket and writes it under `/Library/Tunguska/runtime` with root-only permissions. The app-side provider configuration no longer copies secrets into NetworkExtension preferences because the helper path does not use NetworkExtension.

A Team-signed build may use a data-protection Keychain and an entitled access group. An unsigned or ad-hoc local build falls back to the legacy Keychain without an access group for local UI testing. This is independent from tunnel startup on the helper path.

## Helper security model

- The helper runs as root from `/Library/Tunguska/TunguskaHelper`.
- It listens on `/var/run/tunguska-helper.sock`.
- The socket accepts local connections only after `getpeereid` succeeds and the peer is root or the current console user.
- Requests and responses are small JSON messages; the client closes its write side so the helper can read the complete request.
- The helper never logs the runtime config or profile secrets.
- The helper writes a single active runtime config and removes it on stop/replace.
- Stop sends SIGTERM, waits, escalates to SIGKILL if needed, then removes runtime state.
- The helper observes readiness by looking for the expected TUN address (`172.19.0.1`) in `/sbin/ifconfig`; no UI state may be inferred from a process handle alone.

This is enough for local GitHub-style distribution with explicit admin install, but public binaries should be signed/notarized or distributed as source.

## Backup and diagnostics

`ProfileBackup` and `RedactedDiagnostics` are pure `TunguskaCore` services. A backup payload contains the profiles, the active identifier, and a creation timestamp, but the envelope stores it only as authenticated AES-256-GCM ciphertext. The 256-bit key is derived from a user passphrase with PBKDF2-HMAC-SHA256 (210,000 iterations) and a random salt; the format, version, KDF parameters, salt, and sealed box are explicit in the envelope. Wrong passphrases fail authentication instead of yielding partial profiles. The passphrase is never stored or logged.

Redacted diagnostics are assembled from structured counters rather than by editing sensitive text. The report includes schema/version, app version, storage and tunnel status, profile count, active-profile presence, routing/safety counters, and validation field names. It omits profile IDs, names, endpoints, UUIDs, REALITY keys, short IDs, DNS endpoints, routing domains, and raw share links.

## Runtime distribution

`project.yml` defines the Xcode app, core framework, privileged helper tool, retained packet-tunnel extension, and unit-test target. The helper path builds the app and helper arm64-only. `Resources/Runtime/sing-box` is a pinned sing-box CLI build and is local runtime output; it must not be committed.

`./scripts/build-singbox-cli.sh` builds the pinned sing-box CLI. `./scripts/generate-xcode-project.sh` regenerates the local Xcode project. `./scripts/install-helper.sh` copies `TunguskaHelper`, the `TunguskaCore.framework` it links against, and `sing-box` into `/Library/Tunguska`, writes the LaunchDaemon plist, and loads the service. `./scripts/uninstall-helper.sh` removes them.

The app bundle carries the generated `Resources/Assets.xcassets` icon and accent color. `./scripts/sign-local-adhoc.sh` signs local app/helper artifacts and strips restricted entitlements that AMFI rejects on ad-hoc signatures. The helper path does not need the NetworkExtension entitlement; Gatekeeper warnings remain possible for unsigned local builds.

## Third-party code

sing-box and sing-box-for-apple are GPL-licensed upstream projects. The helper path uses a standalone sing-box CLI built from the pinned source. Copying upstream Swift/Go source requires preserving its license and copyright. Choose the project's distribution license before publishing source or binaries.
