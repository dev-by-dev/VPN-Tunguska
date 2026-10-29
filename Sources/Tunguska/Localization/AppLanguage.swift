import Foundation

/// Supported app languages. The raw value is the stable BCP-47 style code
/// persisted in UserDefaults; `nativeLabel` is the language name in its own
/// form, as shown in the settings picker.
enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case de
    case ru
    case zh

    var id: String { rawValue }

    /// The language name in its own native form (English, Deutsch, Русский, 中文).
    var nativeLabel: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .ru: "Русский"
        case .zh: "中文"
        }
    }

    /// Resolves the default app language from the system's preferred languages.
    /// Supported languages match by prefix (`zh*`/`de`/`ru`); anything else
    /// falls back to English. Injectable for tests.
    static func systemDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let lowercased = identifier.lowercased()
            if lowercased.hasPrefix("zh") { return .zh }
            if lowercased.hasPrefix("de") { return .de }
            if lowercased.hasPrefix("ru") { return .ru }
            if lowercased.hasPrefix("en") { return .en }
        }
        return .en
    }
}
