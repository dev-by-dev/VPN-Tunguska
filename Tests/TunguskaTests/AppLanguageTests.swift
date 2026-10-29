import XCTest
@testable import Tunguska

final class AppLanguageTests: XCTestCase {
    func testSystemDefaultMatchesSupportedLanguages() {
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["ru-RU", "en"]), .ru)
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["de-DE", "en"]), .de)
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["zh-Hans-CN", "en"]), .zh)
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["en-US"]), .en)
    }

    func testSystemDefaultFallsBackToEnglishForUnsupportedLanguages() {
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["fr-FR", "en"]), .en)
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: ["ja-JP"]), .en)
    }

    func testSystemDefaultFallsBackToEnglishWhenEmpty() {
        XCTAssertEqual(AppLanguage.systemDefault(preferredLanguages: []), .en)
    }

    func testNativeLabelsAreDistinct() {
        let labels = Set(AppLanguage.allCases.map(\.nativeLabel))
        XCTAssertEqual(labels.count, AppLanguage.allCases.count)
    }
}
