import XCTest
@testable import Tunguska

final class L10nTests: XCTestCase {
    func testLookupReturnsTranslationForEachLanguage() {
        XCTAssertEqual(L10n.t(L10n.Key.sidebarSettings, language: .en), "Settings")
        XCTAssertEqual(L10n.t(L10n.Key.sidebarSettings, language: .de), "Einstellungen")
        XCTAssertEqual(L10n.t(L10n.Key.sidebarSettings, language: .ru), "Настройки")
        XCTAssertEqual(L10n.t(L10n.Key.sidebarSettings, language: .zh), "设置")
    }

    func testTranslatedFallsBackToEnglishWhenTranslationMissing() {
        let fixture: [String: [AppLanguage: String]] = [
            "test.key": [.en: "Hello", .de: "Hallo"], // ru and zh missing
        ]
        XCTAssertEqual(L10n.translated("test.key", language: .ru, table: fixture), "Hello")
        XCTAssertEqual(L10n.translated("test.key", language: .zh, table: fixture), "Hello")
    }

    func testTranslatedFallsBackToEnglishForUnknownKey() {
        let fixture: [String: [AppLanguage: String]] = [
            "test.key": [.en: "Hello"],
        ]
        XCTAssertEqual(L10n.translated("unknown.key", language: .de, table: fixture), "unknown.key")
    }

    func testEveryKeyHasAllFourTranslations() {
        for (key, translations) in L10n.table {
            for language in AppLanguage.allCases {
                XCTAssertNotNil(
                    translations[language],
                    "Key '\(key)' is missing a \(language.rawValue) translation"
                )
                XCTAssertFalse(
                    translations[language]?.isEmpty ?? true,
                    "Key '\(key)' has an empty \(language.rawValue) translation"
                )
            }
        }
    }

    func testFormatSubstitutesArguments() {
        let formatted = L10n.fmt(
            L10n.Key.homeIdentifiersFormat,
            language: .en,
            2
        )
        XCTAssertFalse(formatted.contains("%"), "Unsubstituted format placeholder in: \(formatted)")
    }
}
