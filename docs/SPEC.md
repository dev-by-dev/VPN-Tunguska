# Tunguska for macOS — Product Specification

## Product goal

A native macOS counterpart to Tunguska for VLESS + REALITY. It should preserve the Android product's safety and routing semantics while using macOS-native interaction, storage, and tunnel APIs.

Initial platform: Apple Silicon, macOS 14+, local development builds.

## Information architecture

- **Home**: confirmed protection state, active profile, routing summary, connect/disconnect, current or exit IP.
- **Profiles**: one active sealed profile, staged paste/QR/JSON import, replace confirmation, redacted technical details.
- **Routing**: default route, Russia direct, custom direct domains, explicit direct/proxy/block rules, offline route test.
- **Security**: Keychain/storage posture, encrypted backup, redacted diagnostics, runtime strategy and advanced diagnostics.
- **Menu bar**: confirmed status and the same start/stop control path as the main app.

## Supported profile shape

- `vless://` and `ess://` share links
- canonical `ProfileIr` JSON compatible with the shared Android model where practical
- VLESS over TCP with REALITY
- `encryption=none` or omitted
- required SNI/server name, REALITY public key and short ID
- optional `flow=xtls-rprx-vision`
- optional `spx` / `spiderX`; effective default `/`
- uTLS fingerprint, default `chrome`

Unsafe TLS flags, debug endpoints, compatibility localhost proxies, unsupported transports, and invalid profiles are rejected. Unsupported non-security query parameters produce warnings.

## Routing semantics

Precedence:

1. Platform per-application policy, when supported by the selected macOS tunnel configuration.
2. Explicit BLOCK.
3. Generated regional DIRECT rules.
4. Explicit DIRECT / PROXY rules.
5. Default route.

Russia direct covers `ru`, `su`, `xn--p1ai`, and runtime GeoIP `ru`. Custom direct domains are suffix rules. Loopback always remains local. Route test is offline and must disclose when runtime GeoIP classification could change its result.

Per-application routing is a platform capability, not an assumed feature. It must only be exposed in the UI when the selected runtime actually enforces it. The initial helper/TUN path does not claim per-application routing.

## Runtime

- Production transport uses the Clash-Verge-style privileged helper: a root `TunguskaHelper` LaunchDaemon starts a pinned standalone `sing-box` CLI.
- The app and helper share only validated helper commands and the generated sing-box document; the helper does not expose arbitrary root commands.
- Runtime state comes from helper status and a live TUN interface observation, never from a button's desired state.
- No sing-box Clash API, debug endpoint, or unauthenticated local proxy.
- Runtime configuration is generated from the same validated profile used by the preview.
- XRAY remains behind the engine protocol as a later strategy; it is not advertised as available before it works.

## Storage and export

- Profile secrets and automation credentials: Keychain.
- Non-secret UI preferences: UserDefaults.
- Full backups: authenticated encryption using CryptoKit.
- Diagnostics: redacted by construction; no UUID, REALITY key, short ID, raw share link, or token.

## Initial acceptance criteria

1. VLESS and ESS import validates and previews the same fields as Android.
2. Invalid and unsafe profiles fail before storage.
3. Route preview preserves BLOCK/regional/explicit/default precedence.
4. Keychain save/read/replace does not write profile secrets to preferences or logs.
5. The app builds and displays all four primary sections on Apple Silicon.
6. A real sing-box helper/TUN session starts and stops, with live IP/interface verification.
7. A runtime failure returns to a non-connected state and tears down the tunnel.
8. Russia direct and custom direct rules are present in the generated runtime configuration.

## Explicit non-goals for the first local build

- Intel binaries
- Mac App Store distribution
- Multi-profile library and subscription-first UX
- A macOS equivalent of Android application freezing
- A second XRAY runtime advertised as finished
- Claims that domain splitting hides the existence of a VPN from another running process
