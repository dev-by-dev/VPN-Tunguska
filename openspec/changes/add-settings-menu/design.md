# Design

## Context

See proposal.md - Why. Current state relevant to the approach:

- The app is a single SwiftUI target (`Sources/Tunguska`, ~1,150 lines of views)
  with a `NavigationSplitView` whose sidebar is driven by `AppModel.Section`
  (`home`, `profiles`, `routing`, `security`). There is no Settings view; the
  existing `AppSettings` (UserDefaults-backed, `@MainActor`, `@Published`) persists
  preferences but is not surfaced anywhere.
- No localization infrastructure exists: every user-facing string is a hardcoded
  English literal in views (`Text("...")`, `Label(...)`), in app-layer state
  (`TunnelObservedState.title/detail`, `TunnelControllerError`, `AppModelError`,
  `AppSettings.Appearance.label`, section rawValues), and in `MenuBarContentView`.
- User-facing strings also flow from `TunguskaCore` (profile validation issues,
  import parser errors) via `error.localizedDescription` and are rendered as-is.
- Tests live in `Tests/TunguskaCoreTests`; the app target currently has no test
  target. `swift build --target Tunguska` and `swift test` must keep passing
  (`scripts/validate-local.sh`).

## Goals / Non-Goals

**Goals:**

- A custom runtime localization layer that supports switching languages without
  an app restart (SwiftUI-native `.xcstrings` alone cannot do this reliably).
- One settings sidebar section with a language picker as its first preference
  group, built so more preference groups can be added later.
- All four languages fully translated for every app-layer string.

**Non-Goals:**

- Localizing `TunguskaCore` diagnostic messages (validation issues, import parser
  errors). They pass through to the UI as dynamic error detail in English in this
  change; a future change can inject a locale/bundle into the core.
- Right-to-left layout, pluralization rules, and per-region formatting beyond
  choosing one of four languages.
- Localizing the privileged helper (`TunguskaHelper`) or the `sing-box` CLI; they
  have no user-facing UI in this app.
- A separate macOS Settings window (`Settings` scene / Cmd+,); the settings live
  in the app's sidebar per the agreed scope.

## Decisions

### Decision: Custom runtime `L10n` layer instead of String Catalogs

Implement a small app-layer localization layer: `AppLanguage` enum
(`en`, `de`, `ru`, `zh`) with `allCases`, a stable string key for each message,
and a string table holding all four translations per key. Views resolve text via
a function on the shared `AppSettings` (e.g. `settings.t("sidebar.settings")`)
or a free `L10n` function reading `AppSettings.shared.appLanguage`.

- **Why:** macOS resolves String Catalogs against the process locale at bundle
  level; changing language at runtime requires either an app restart
  (`AppleLanguages` in UserDefaults) or bundle swizzling. The spec requires
  restart-free switching, so a runtime lookup keyed off observable
  `AppSettings.appLanguage` is the reliable path.
- **Alternative considered:** `.xcstrings` + `AppleLanguages` override with a
  restart prompt. Rejected: violates the restart-free requirement and degrades UX.
- **Alternative considered:** Method swizzling `Bundle.main` per view.
  Rejected: fragile, hard to test, and unnecessary for this app size.

### Decision: Language stored in `AppSettings`, defaulting from the system

Add `@Published var appLanguage: AppLanguage` to `AppSettings`, persisted under a
new UserDefaults key (`tunguska.settings.appLanguage`). On first launch, resolve
the default from `Locale.preferredLanguages.first`, matching the `zh*`/`de`/`ru`
prefixes to the enum, falling back to English. Selection logic lives in
`AppSettings` so it is testable and consistent for both settings UI and tests.

- **Why:** `AppSettings` already owns persisted preferences and is injected as an
  environment object; adding one more `@Published` property gives every view
  automatic re-render on language change through SwiftUI's observation.
- **Alternative considered:** A separate `LocalizationManager` observable object.
  Rejected: splits preference state across two owners for no benefit at this size.

### Decision: String table as typed Swift source, not .strings/.xcstrings files

Keep translations in Swift (a static dictionary keyed by a case-less string enum
or string constants) inside `Sources/Tunguska/Localization/`.

- **Why:** Compile-time key checking (typo in a key fails the build), no XcodeGen
  resource-wiring changes, trivial to unit test, and the table is small
  (~150-200 strings). `project.yml` already enumerates sources, so new Swift
  files need no project changes.
- **Alternative considered:** Per-language `.strings` files or a JSON bundle.
  Rejected: loses compile-time safety and adds resource plumbing for no gain at
  this scale. If the table grows past a few hundred strings, migrate to
  `.xcstrings` later.

### Decision: Fallback to English on missing keys

The lookup function returns the English translation when the active language has
no entry for a key, and a runtime assertion (debug only) flags the gap during
development.

- **Why:** Guarantees no empty or key-dump text in production (spec: missing
  translation falls back to English), while making gaps visible to developers.

### Decision: App-layer tests via a new `TunguskaTests` target on the executable

The package has no test target for the `Tunguska` app target (only
`TunguskaCoreTests`, which depends on `TunguskaCore`). Add a `TunguskaTests`
test target to `Package.swift` that depends on the `Tunguska` executable target
(SwiftPM has supported test→executable dependencies since tools 5.5; the package
uses 6.0), and mirror it in `project.yml` so the generated Xcode project stays in
sync. Localization and language-persistence tests live there and run under the
existing `swift test` path.

- **Why:** Keeps the localization layer in the app target where it is used,
  while making it unit-testable without moving platform UI concerns into
  `TunguskaCore`.
- **Alternative considered:** A separate `TunguskaL10n` library target.
  Rejected: an extra target in `Package.swift` and `project.yml` plus helper
  embedding is heavier than needed for one module.
- **Alternative considered:** Putting L10n in `TunguskaCore`. Rejected: the core
  is platform-independent profile/import/routing logic; UI language is an app
  concern.

### Decision: Settings section reuses the existing sidebar pattern

Add `case settings` to `AppModel.Section` with a new SF Symbol icon, and a
`SettingsView` rendered in `RootView.detailView`, following the same
`PanelCard`-based layout as the other views. The language group is a `Picker`
bound to `AppSettings.appLanguage`.

- **Why:** Consistent with the established navigation, minimal intrusion, and the
  section enum drives both the sidebar list and the detail switch.
- **Alternative considered:** macOS `Settings` scene with `Form` in a separate
  window. Rejected per agreed scope (sidebar placement chosen by the user).

## Risks / Trade-offs

- [Large string surface in one change (~150-200 keys × 4 languages) is
  translation-heavy] → Centralize the table in one file, translate mechanically,
  and add a unit test that every key has all four translations so gaps are caught
  in CI (`swift test`).
- [Forgetting to route a new/existing string through L10n] → Convetion: all new
  user-facing strings must use the lookup; code review + the four-language
  completeness test keep the table honest. Add a brief note to the README project
  layout section.
- [Core (`TunguskaCore`) error messages stay English] → Accept for this change;
  they are diagnostic detail, not UI chrome. Surface them in a follow-up if users
  ask.
- [Manual runtime lookup can be bypassed, silently reverting to hardcoded
  strings] → The completeness test only guards the table, not call sites; keep the
  conversion mechanical and complete in this change so no hardcoded literals
  remain in `Sources/Tunguska/Views`.
- [Chinese/German/Russian translations may be imperfect] → Acceptable for v1; the
  structure makes corrections a one-line table edit.

## Migration Plan

No data or settings migration is required: the new UserDefaults key is absent on
existing installs, which simply triggers the system-language default resolution.
Rollback is reverting the change; no persisted state becomes invalid.
