# UI Localization Specification

## Purpose

Makes every piece of user-facing text in the app resolvable at runtime in the
user's chosen language (English, German, Russian, Chinese) so the whole interface,
not just the settings screen, reflects the selection immediately.

## Requirements

### Requirement: UI text resolves in all supported languages
All user-facing text rendered by the app SHALL be resolved through the app's
localization layer and SHALL have a translation for each of the four supported
languages: English, German, Russian, and Chinese. Coverage SHALL include the
sidebar section names, every main view (Home, Profiles, Routing, Security,
Settings), the menu bar extra content, and app-generated status and error labels
that originate in the app layer.

#### Scenario: Sidebar names are localized
- **WHEN** the active language is Chinese
- **THEN** the sidebar shows the localized Chinese names for all sections, including Settings

#### Scenario: Main views are localized
- **WHEN** the active language is German and the user opens the Routing view
- **THEN** all static labels, buttons, and panel titles in that view appear in German

#### Scenario: Menu bar extra is localized
- **WHEN** the active language is Russian
- **THEN** the menu bar extra shows its labels (connect/disconnect, open, quit, status text) in Russian

### Requirement: Missing translation falls back to English
When the localization layer has no translation for a key in the active language,
it SHALL render the English text for that key. The fallback SHALL NOT crash or
render an empty string.

#### Scenario: Untranslated key renders in English
- **WHEN** a string key has a German translation missing and the active language is German
- **THEN** the UI shows the English text for that key

### Requirement: Language change applies without restart
When the active language changes, all visible user-facing text SHALL re-render in
the new language immediately, without restarting the app. This SHALL apply to
windows and surfaces already on screen, including the menu bar extra.

#### Scenario: Switching language live
- **WHEN** the user changes the language from English to Russian in Settings
- **THEN** every visible label, including the settings view itself and the menu bar extra, re-renders in Russian without an app restart

### Requirement: Language state is observable app-wide
The app SHALL expose the active language as observable state so any view can
re-render when the language changes. Views SHALL NOT cache resolved strings
across language changes.

#### Scenario: Newly opened view uses current language
- **WHEN** the language is German and the user switches from Home to Profiles
- **THEN** the Profiles view renders in German
