import XCTest
@testable import Tunguska

@MainActor
final class AppSettingsLanguageTests: XCTestCase {
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "tunguska.tests.\(UUID().uuidString)"
    }

    override func tearDown() {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    func testAppLanguagePersistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.appLanguage, AppLanguage.systemDefault())

        settings.appLanguage = .de
        XCTAssertEqual(defaults.string(forKey: "tunguska.settings.appLanguage"), "de")

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .de)
    }

    func testAppLanguageUnknownStoredValueFallsBackToSystemDefault() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("xx", forKey: "tunguska.settings.appLanguage")
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.appLanguage, AppLanguage.systemDefault())
    }

    func testSettingsLookupUsesActiveLanguage() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)
        settings.appLanguage = .ru
        XCTAssertEqual(settings.t(L10n.Key.sidebarSettings), "Настройки")
        settings.appLanguage = .zh
        XCTAssertEqual(settings.t(L10n.Key.sidebarSettings), "设置")
    }

    func testPickerSelectionMatchesBindingSourceOfTruth() {
        // The SettingsView picker is bound to `$settings.appLanguage`; reading
        // the property back must reflect the selection immediately and after reload.
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: defaults)

        settings.appLanguage = .de
        XCTAssertEqual(settings.appLanguage, .de)

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .de)
    }
}
