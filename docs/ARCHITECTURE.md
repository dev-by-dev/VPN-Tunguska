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
        └── TunnelController ────── NETunnelProviderManager / Session
                                      │
                                      ▼
                           TunguskaTunnel extension
                                      │
                    ProfileKeychainStore → SingBoxConfigurationBuilder
                                      │
                           Libbox + PlatformInterface + TUN
                                      │
                              sing-box / REALITY
```

`TunguskaCore` has no SwiftUI or NetworkExtension dependency. This keeps import, routing, and configuration semantics testable without a signed tunnel. `Sources/TunguskaTunnel` resolves the selected profile from the shared Keychain store, validates and builds the sing-box configuration, then starts the pinned libbox command server and TUN provider. Startup is fail-closed: any missing profile, invalid configuration, setup failure, or TUN failure is returned to NetworkExtension instead of producing a connected state.

## State ownership

- `AppModel` owns presentation state on the main actor.
- `TunnelController` owns VPN preferences and session transitions.
- The packet-tunnel provider owns the live engine and reports health/errors.
- Desired user state and observed runtime state are separate values.

## Import and persistence

Import is staged: input → validation → normalized preview → explicit confirmation → Keychain replacement. Import never starts VPN automatically. The UI masks stored UUID/REALITY material and keeps desired tunnel state separate from the NetworkExtension-observed session state.

The app and packet-tunnel extension use the same `ProfileKeychainStore` service and a shared Keychain access group. The provider receives only the profile identifier and public endpoint in `providerConfiguration`; it loads the sealed profile itself. A Team-signed build uses the data-protection Keychain with the entitled access group. An unsigned or ad-hoc local build falls back to the legacy Keychain without an access group, which is sufficient for local UI/Keychain testing but cannot start the NetworkExtension.

## Backup and diagnostics

`ProfileBackup` and `RedactedDiagnostics` are pure `TunguskaCore` services. A backup payload contains the profiles, the active identifier, and a creation timestamp, but the envelope stores it only as authenticated AES-256-GCM ciphertext. The 256-bit key is derived from a user passphrase with PBKDF2-HMAC-SHA256 (210,000 iterations) and a random salt; the format, version, KDF parameters, salt, and sealed box are explicit in the envelope. Wrong passphrases fail authentication instead of yielding partial profiles. The passphrase is never stored or logged.

Redacted diagnostics are assembled from structured counters rather than by editing sensitive text. The report includes schema/version, app version, storage and tunnel status, profile count, active-profile presence, routing/safety counters, and validation field names. It omits profile IDs, names, endpoints, UUIDs, REALITY keys, short IDs, DNS endpoints, routing domains, and raw share links.

## Runtime distribution

The app-side `TunnelController` stores only the Keychain profile identifier and public endpoint summary in the NetworkExtension provider configuration; secrets remain in the shared Keychain profile store. The initial local build targets a packet-tunnel app extension. A standalone Developer ID build may require a system-extension packaging variant; this is a distribution decision, not a reason to maintain two runtime implementations.

`project.yml` defines the Xcode app, core framework, packet-tunnel extension, and unit-test target for full Xcode builds. `Vendor/Libbox.xcframework` is a static arm64/x86_64 archive; the app and extension themselves are arm64-only. `./scripts/build-libbox-macos.sh` builds the pinned sing-box revision, and `./scripts/generate-xcode-project.sh` regenerates the local project. The generated `Tunguska.xcodeproj`, libbox framework, and local signing files are not committed.

The app bundle carries the generated `Resources/Assets.xcassets` icon and accent color. `./scripts/sign-local-adhoc.sh` strips restricted entitlements that AMFI rejects on ad-hoc signatures and signs the core, extension, and app for local UI/Keychain smoke tests. It cannot enable NetworkExtension or a shared Keychain group; those require a development team and provisioning.

## Third-party code

sing-box and sing-box-for-apple are GPL-licensed upstream projects. The initial implementation uses the libbox API and studies upstream integration behavior. Copying upstream Swift/Go source requires preserving its license and copyright. Choose the project's distribution license before publishing source or binaries.
