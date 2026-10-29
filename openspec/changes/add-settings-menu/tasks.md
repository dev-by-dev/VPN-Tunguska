# Tasks

Reference: `specs/settings-menu/spec.md`, `specs/ui-localization/spec.md`, and
`design.md` for the approach (runtime `L10n` layer, `AppSettings.appLanguage`,
sidebar Settings section, `TunguskaTests` target).

## 1. Localization foundation

- [x] 1.1 Create `Sources/Tunguska/Localization/AppLanguage.swift` with the `AppLanguage` enum (`en`, `de`, `ru`, `zh`; `CaseIterable`, `Identifiable`), a native-form label per case (English, Deutsch, Русский, 中文), and system-default resolution from `Locale.preferredLanguages` with English fallback. Verify: `swift build --target Tunguska` succeeds.
- [x] 1.2 Create `Sources/Tunguska/Localization/L10n.swift` with a stable string-key namespace, a four-language string table, and the lookup function that renders in the active language and falls back to English for missing keys (debug-only assertion on gaps). Verify: `swift build --target Tunguska` succeeds.
- [x] 1.3 Add `@Published var appLanguage: AppLanguage` to `AppSettings` (new UserDefaults key `tunguska.settings.appLanguage`, persisted in `didSet`, initialized from system default when absent) and inject `AppSettings.shared` as an environment object in `TunguskaApp` for both the window and the menu bar extra. Verify: `swift build --target Tunguska` succeeds.
- [x] 1.4 Add a `TunguskaTests` test target to `Package.swift` (path `Tests/TunguskaTests`, dependency on the `Tunguska` executable target) and mirror it in `project.yml` (bundle.unit-test target depending on `Tunguska`); regenerate the Xcode project with `scripts/generate-xcode-project.sh`. Verify: `swift test` runs the new (empty) target successfully.
- [x] 1.5 Write unit tests covering: system-language default resolution (supported → match, e.g. `ru-RU` → `ru`; unsupported → `en`), `appLanguage` persistence round-trip in an injected `UserDefaults` suite, lookup returning the correct translation per language, English fallback for a missing key, and a completeness check that every key has all four translations. Verify: `swift test` passes.

## 2. Settings section and view

- [x] 2.1 Add a `settings` case to `AppModel.Section` with a sidebar icon, localized through the L10n layer (sidebar labels no longer use raw enum values). Verify: `swift build --target Tunguska` succeeds.
- [x] 2.2 Create `Sources/Tunguska/Views/SettingsView.swift` following the existing `PanelCard` layout, with a Language preference group whose `Picker` offers exactly English, Deutsch, Русский, 中文 (native labels), bound to `AppSettings.appLanguage`. Verify: `swift build --target Tunguska` succeeds.
- [x] 2.3 Wire `SettingsView` into `RootView.detailView` for the new `.settings` section. Verify: launch the app (or use the existing `-open-section-*` smoke-test argument pattern) and confirm the sidebar shows Settings and opens the settings view.
- [x] 2.4 Test that the picker selection is reflected as selected on re-open and persists across relaunch (covered by 1.5 persistence test; here verify the binding shows the current value when the settings view appears). Verify: unit test in `TunguskaTests` reads `AppSettings.appLanguage` after setting it and matches the picker source of truth.

## 3. Localize the existing UI

- [x] 3.1 Route every user-facing string through the L10n layer: all views (`HomeView`, `ProfilesView`, `RoutingView`, `SecurityView`, `SharedViews`, `RootView` including `MenuBarContentView`) plus app-layer strings (`TunnelObservedState.title/detail`, `TunnelControllerError`, `AppModelError`, `AppSettings.Appearance.label`, sidebar section names). Verify: no hardcoded user-facing string literals remain in `Sources/Tunguska/Views` (grep), and `swift build --target Tunguska` succeeds.
- [x] 3.2 Fill in the German translations for the full key set. Verify: the 1.5 completeness test passes and a spot-check renders German strings.
- [x] 3.3 Fill in the Russian translations for the full key set. Verify: the 1.5 completeness test passes and a spot-check renders Russian strings.
- [x] 3.4 Fill in the Chinese translations for the full key set. Verify: the 1.5 completeness test passes and a spot-check renders Chinese strings.
- [x] 3.5 Document the L10n convention (all new user-facing strings go through the lookup; the four-language completeness test guards the table) in the README project-layout section. Verify: README renders the new note.

## 4. Integration validation

- [x] 4.1 Run `./scripts/validate-local.sh` and confirm `swift build --target Tunguska`, `swift build --target TunguskaHelper`, `swift test`, and `swift run TunguskaCoreCheck` all pass.
- [x] 4.2 Manual smoke test of the acceptance scenarios: Settings opens from the sidebar; the picker lists exactly four languages in native form; switching to each language re-renders the whole UI including the menu bar extra without restart; the selection survives relaunch; first launch on an unsupported system language falls back to English. Verify: observed behavior matches `specs/settings-menu/spec.md` and `specs/ui-localization/spec.md`.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
