import Combine
import Foundation
import ServiceManagement
import SwiftUI
import TunguskaCore

/// App-level preferences persisted in UserDefaults, mirroring the Clash Verge
/// settings blocks: general behavior, connection defaults, system proxy, and
/// maintenance. Owned by the app process and injected as an environment object.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        func label(language: AppLanguage) -> String {
            switch self {
            case .system: L10n.t(L10n.Key.settingsAppearanceSystem, language: language)
            case .light: L10n.t(L10n.Key.settingsAppearanceLight, language: language)
            case .dark: L10n.t(L10n.Key.settingsAppearanceDark, language: language)
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            syncLoginItem()
        }
    }

    @Published var silentStart: Bool {
        didSet { defaults.set(silentStart, forKey: Keys.silentStart) }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var autoConnect: Bool {
        didSet { defaults.set(autoConnect, forKey: Keys.autoConnect) }
    }

    @Published var proxyPort: Int {
        didSet {
            guard (Self.validPortRange).contains(proxyPort) else { return }
            defaults.set(proxyPort, forKey: Keys.proxyPort)
        }
    }

    @Published var proxyGuardEnabled: Bool {
        didSet { defaults.set(proxyGuardEnabled, forKey: Keys.proxyGuardEnabled) }
    }

    @Published var proxyGuardInterval: Int {
        didSet {
            guard (Self.validGuardIntervalRange).contains(proxyGuardInterval) else { return }
            defaults.set(proxyGuardInterval, forKey: Keys.proxyGuardInterval)
        }
    }

    /// The active UI language. Persisted; on first launch resolved from the
    /// system language with English fallback (see `AppLanguage.systemDefault`).
    @Published var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    /// Populated when macOS refuses the launch-at-login registration.
    @Published private(set) var loginItemError: String?

    static let validPortRange = 1024 ... 65_535
    static let validGuardIntervalRange = 5 ... 300
    static let defaultGuardInterval = 10

    private let defaults: UserDefaults

    private enum Keys {
        static let launchAtLogin = "tunguska.settings.launchAtLogin"
        static let silentStart = "tunguska.settings.silentStart"
        static let appearance = "tunguska.settings.appearance"
        static let autoConnect = "tunguska.settings.autoConnect"
        static let proxyPort = "tunguska.settings.proxyPort"
        static let proxyGuardEnabled = "tunguska.settings.proxyGuardEnabled"
        static let proxyGuardInterval = "tunguska.settings.proxyGuardInterval"
        static let appLanguage = "tunguska.settings.appLanguage"
    }

    /// Internal (not private) so tests can inject an isolated UserDefaults suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Assignments during initialization do not trigger the observers above.
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        silentStart = defaults.bool(forKey: Keys.silentStart)
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        autoConnect = defaults.bool(forKey: Keys.autoConnect)
        let storedPort = defaults.integer(forKey: Keys.proxyPort)
        proxyPort = Self.validPortRange.contains(storedPort) ? storedPort : HelperProtocol.defaultProxyPort
        proxyGuardEnabled = defaults.bool(forKey: Keys.proxyGuardEnabled)
        let storedInterval = defaults.integer(forKey: Keys.proxyGuardInterval)
        proxyGuardInterval = Self.validGuardIntervalRange.contains(storedInterval)
            ? storedInterval
            : Self.defaultGuardInterval
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: Keys.appLanguage) ?? "")
            ?? AppLanguage.systemDefault()
    }

    /// Localizes a string key in the currently active language. Views observe
    /// `appLanguage`, so text resolved through this helper re-renders when the
    /// language changes.
    func t(_ key: String) -> String {
        L10n.t(key, language: appLanguage)
    }

    /// Format-string lookup in the active language (`%@`/`%d` templates).
    func fmt(_ key: String, _ arguments: CVarArg...) -> String {
        L10n.fmt(key, language: appLanguage, arguments)
    }

    /// Registers or unregisters the app as a login item. Debug builds running
    /// from DerivedData may be refused by macOS; the error is surfaced in the UI.
    private func syncLoginItem() {
        do {
            let service = SMAppService.mainApp
            if launchAtLogin {
                guard service.status != .enabled else {
                    loginItemError = nil
                    return
                }
                try service.register()
            } else {
                guard service.status == .enabled else {
                    loginItemError = nil
                    return
                }
                try service.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = launchAtLogin
                ? L10n.fmt(L10n.Key.errorLoginItemEnableFormat, error.localizedDescription)
                : L10n.fmt(L10n.Key.errorLoginItemDisableFormat, error.localizedDescription)
        }
    }
}
