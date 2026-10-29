# Proposal

## Why

The Tunguska app UI is hardcoded English with no localization infrastructure and no
settings surface at all: `AppSettings` persists preferences (appearance, launch at
login, proxy guard, etc.) that the user cannot view or change. Users who speak German,
Russian, or Chinese cannot use the app in their language, and there is no place to
select one. A settings section with language selection (English, German, Russian,
Chinese) fixes both gaps in one coherent feature.

## What Changes

- Add a **Settings** section to the main window sidebar (alongside Home, Profiles,
  Routing, Security) containing app preferences. The first preference group is
  **Language** with a picker for English, German, Russian, and Chinese.
- Introduce an app-level localization layer that every user-facing string goes
  through, with string tables for all four languages.
- Localize the entire existing UI (Home, Profiles, Routing, Security, menu bar
  extra, dialogs/errors surfaced by the app) so switching the language re-renders
  the whole app in the selected language.
- Persist the selected language in `AppSettings` (UserDefaults); default to the
  system language on first launch with English as fallback. Applying a language
  takes effect immediately, without restarting the app.
- Add unit tests for the localization layer and language persistence.

## Capabilities

### New Capabilities

- `settings-menu`: The app exposes a Settings section in the main window where the
  user can view and edit app preferences; the first preference group is language
  selection (English, German, Russian, Chinese) with persistent, restart-free effect.
- `ui-localization`: All user-facing text in the app is resolved through a
  localization layer supporting English, German, Russian, and Chinese; the active
  language follows the system language by default, can be overridden in Settings,
  and switching re-renders the UI immediately.

### Modified Capabilities

<!-- None: the project has no existing specs. -->

## Impact

- `Sources/Tunguska/Views/` — all views get localized strings; new `SettingsView`.
- `Sources/Tunguska/State/AppSettings.swift` — new persisted `appLanguage` setting.
- `Sources/Tunguska/State/AppModel.swift` — new `.settings` sidebar section.
- New localization module/string tables (per-language string resources) under
  `Sources/Tunguska` and `Resources`.
- `Tests/TunguskaCoreTests` (or a new test target location for app-level tests)
  — tests for language resolution, fallback, and persistence.
- No changes to `TunguskaCore`, the helper daemon, the tunnel protocol, or any
  security-critical path; profile data, Keychain storage, and diagnostics
  redaction are untouched.
