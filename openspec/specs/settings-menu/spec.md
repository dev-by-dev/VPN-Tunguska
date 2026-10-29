# Settings Menu Specification

## Purpose

Gives the user a dedicated Settings surface in the main window to view and edit
app preferences, starting with the language preference that drives the app's
localized UI.

## Requirements

### Requirement: Settings section in the main window
The app SHALL display a "Settings" entry in the main window sidebar alongside the
existing sections (Home, Profiles, Routing, Security). Selecting it SHALL show the
settings view in the detail area. The entry SHALL be visible in the same list and
styled like the other sidebar entries.

#### Scenario: Opening the settings view
- **WHEN** the user clicks the "Settings" entry in the sidebar
- **THEN** the detail area replaces the current view with the settings view

#### Scenario: Settings is reachable from the default view
- **WHEN** the app has just launched and shows the home view
- **THEN** the sidebar contains a selectable "Settings" entry

### Requirement: Language preference control
The settings view SHALL provide a language preference group offering exactly four
selectable languages: English, German, Russian, and Chinese. Each language SHALL be
labeled in its own native form (English, Deutsch, Русский, 中文). The control SHALL
display the currently active language as selected.

#### Scenario: Picker lists all four languages
- **WHEN** the user opens the settings view
- **THEN** the language group shows the options English, Deutsch, Русский, and 中文

#### Scenario: Current language is indicated
- **WHEN** the active language is Russian
- **THEN** the language control shows Русский as the selected option

### Requirement: Language selection persists across launches
The app SHALL persist the user's language selection across app restarts. On first
launch, when the user has never chosen a language, the app SHALL follow the system
language if it is one of the supported languages, and SHALL fall back to English
otherwise.

#### Scenario: Selection survives restart
- **WHEN** the user selects German and then restarts the app
- **THEN** the app starts with German as the active language and Deutsch shown as selected in settings

#### Scenario: First launch uses the system language
- **WHEN** the app launches for the first time on a system whose language is Russian
- **THEN** the active language is Russian

#### Scenario: Unsupported system language falls back to English
- **WHEN** the app launches for the first time on a system whose language is French
- **THEN** the active language is English
