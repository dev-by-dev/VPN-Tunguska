import Combine
import Foundation
import SwiftUI
import TunguskaCore

@MainActor
final class AppModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case home = "Home"
        case profiles = "Profiles"
        case routing = "Routing"
        case security = "Security"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .home: "gauge.with.needle"
            case .profiles: "rectangle.on.rectangle"
            case .routing: "arrow.triangle.branch"
            case .security: "lock.shield"
            }
        }
    }

    @Published private(set) var profiles: [ProfileIr] = []
    @Published private(set) var activeProfileID: String?
    @Published var importText: String = ""
    @Published private(set) var importPreview: ImportedProfile?
    @Published private(set) var importError: String?
    @Published private(set) var storageError: String?
    /// TUN vs system-proxy capture mode; persisted in UserDefaults.
    @Published private(set) var tunnelMode: HelperCommandMode = {
        if let raw = UserDefaults.standard.string(forKey: "tunguska.tunnel.mode"),
           let mode = HelperCommandMode(rawValue: raw) {
            return mode
        }
        return .tun
    }()
    @Published private(set) var profileValidationMessage: String?
    @Published private(set) var tunnelError: String?

    let tunnelController = TunnelController()

    private let store: ProfileKeychainStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: ProfileKeychainStore = .shared) {
        self.store = store
        tunnelController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        reloadProfiles()
        tunnelController.refresh()
    }

    var activeProfile: ProfileIr? {
        profiles.first { $0.id == activeProfileID }
    }

    var activeProfileBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.activeProfileID ?? "" },
            set: { [weak self] in self?.selectProfile(id: $0) }
        )
    }

    /// Quits the app from the menu bar. Tears down an active tunnel first so
    /// the root-side sing-box process does not keep running unsupervised.
    func quitFromMenuBar() {
        let shouldDisconnect = tunnelController.observedState == .connected || tunnelController.isPreparing
        Task { @MainActor in
            if shouldDisconnect {
                await disconnectTunnel()
            }
            NSApp.terminate(nil)
        }
    }

    func selectProfile(id: String) {
        guard !id.isEmpty else { return }
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        storageError = nil
        do {
            try store.setActiveProfileID(id)
        } catch {
            storageError = error.localizedDescription
        }
    }

    func reloadProfiles() {
        do {
            profiles = try store.loadAll()
            let storedActiveID = try store.loadActiveProfileID()
            activeProfileID = profiles.contains(where: { $0.id == storedActiveID }) ? storedActiveID : profiles.first?.id
            if let activeProfileID {
                try store.setActiveProfileID(activeProfileID)
            }
            storageError = nil
        } catch {
            profiles = []
            activeProfileID = nil
            storageError = error.localizedDescription
        }
    }

    func stageImport() {
        importError = nil
        profileValidationMessage = nil
        do {
            importPreview = try ProfileImportParser.parse(importText)
        } catch {
            importPreview = nil
            importError = error.localizedDescription
        }
    }

    func confirmImport() {
        guard let importPreview else { return }
        do {
            try store.save(importPreview.profile)
            reloadProfiles()
            selectProfile(id: importPreview.profile.id)
            self.importPreview = nil
            importText = ""
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    func discardImport() {
        importPreview = nil
        importError = nil
    }

    func deleteProfile(id: String) {
        guard tunnelController.observedState != .connected else {
            storageError = "Disconnect the active VPN session before deleting a profile."
            return
        }
        do {
            try store.deleteProfile(id: id)
            if activeProfileID == id {
                activeProfileID = nil
                try store.setActiveProfileID(nil)
            }
            reloadProfiles()
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }

    func updateActiveProfile(_ transform: (inout ProfileIr) -> Void) {
        guard var profile = activeProfile else { return }
        transform(&profile)
        let issues = profile.validationIssues()
        guard issues.isEmpty else {
            profileValidationMessage = issues.map { "\($0.field): \($0.message)" }.joined(separator: "\n")
            return
        }

        do {
            try store.save(profile)
            reloadProfiles()
            profileValidationMessage = nil
        } catch {
            profileValidationMessage = error.localizedDescription
        }
    }

    func evaluateRoutePreview(_ form: RoutePreviewForm) -> RoutePreviewEvaluation {
        guard let profile = activeProfile else {
            return .failure("Select a profile before evaluating a route.")
        }
        guard let destinationPort = form.portValue else {
            return .failure("Destination port must be empty or an integer between 1 and 65535.")
        }

        let request = RoutePreviewRequest(
            packageName: form.packageName.nilIfBlank,
            destinationHost: form.destinationHost.nilIfBlank,
            destinationIp: form.destinationIp.nilIfBlank,
            destinationPort: destinationPort,
            protocol: NetworkProtocol(rawValue: form.protocolName)
        )
        do {
            return .success(try RoutePreviewEngine.evaluate(profile, request: request))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func clearTunnelError() {
        tunnelError = nil
    }

    /// Switches the capture mode. Ignored while a session is active so a running
    /// TUN or system-proxy session is never reconfigured mid-flight.
    func setTunnelMode(_ mode: HelperCommandMode) {
        guard mode != tunnelMode else { return }
        switch tunnelController.observedState {
        case .connected, .connecting, .disconnecting:
            return
        default:
            break
        }
        tunnelMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "tunguska.tunnel.mode")
    }

    func connectActiveProfile() async {
        tunnelError = nil
        guard let profile = activeProfile else {
            tunnelError = "Import and select a profile before starting the VPN."
            return
        }
        do {
            try await tunnelController.connect(profile: profile, mode: tunnelMode)
        } catch {
            tunnelError = error.localizedDescription
        }
    }

    func disconnectTunnel() async {
        tunnelError = nil
        do {
            try await tunnelController.disconnect()
        } catch {
            tunnelError = error.localizedDescription
        }
    }

    func exportBackup(passphrase: String) throws -> Data {
        try ProfileBackup.export(
            profiles: profiles,
            activeProfileID: activeProfileID,
            passphrase: passphrase
        )
    }

    @discardableResult
    func importBackup(data: Data, passphrase: String) throws -> Int {
        guard tunnelController.observedState != .connected,
              tunnelController.observedState != .connecting else {
            throw AppModelError.vpnMustBeStopped
        }

        let payload = try ProfileBackup.import(data: data, passphrase: passphrase)
        for profile in payload.profiles {
            try store.save(profile)
        }
        if let importedActiveID = payload.activeProfileID {
            try store.setActiveProfileID(importedActiveID)
        }
        reloadProfiles()
        if let storageError {
            throw AppModelError.storage(storageError)
        }
        return payload.profiles.count
    }

    func diagnosticsReport() throws -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return try RedactedDiagnostics.build(
            profiles: profiles,
            activeProfileID: activeProfileID,
            appVersion: "\(version) (\(build))",
            storage: "macOS Keychain, this-device accessibility",
            tunnelStatus: tunnelController.observedState.title
        )
    }
}

enum AppModelError: LocalizedError {
    case vpnMustBeStopped
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .vpnMustBeStopped:
            return "Stop the VPN before restoring a profile backup."
        case .storage(let message):
            return message
        }
    }
}

enum RoutePreviewEvaluation: Equatable {
    case success(RoutePreviewOutcome)
    case failure(String)
}

struct RoutePreviewForm: Equatable {
    var packageName: String = ""
    var destinationHost: String = ""
    var destinationIp: String = ""
    var destinationPort: String = ""
    var protocolName: String = ""

    var portValue: Int? {
        let value = destinationPort.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard let port = Int(value), (1 ... 65_535).contains(port) else { return nil }
        return port
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
