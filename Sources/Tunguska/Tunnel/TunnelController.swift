@preconcurrency import Foundation
@preconcurrency import NetworkExtension
import TunguskaCore

enum TunnelObservedState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed(String)
    case unavailable(String)

    var title: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .disconnecting: "Disconnecting"
        case .failed: "Failed"
        case .unavailable: "Unavailable"
        }
    }

    var detail: String {
        switch self {
        case .disconnected:
            "No live NetworkExtension session is active."
        case .connecting:
            "NetworkExtension is establishing a session; the UI remains non-connected until it reports success."
        case .connected:
            "A live NetworkExtension session reported the connected state."
        case .disconnecting:
            "NetworkExtension is stopping the active session."
        case let .failed(message):
            message
        case let .unavailable(message):
            message
        }
    }
}

enum TunnelControllerError: LocalizedError {
    case invalidProfile([ValidationIssue])
    case missingProviderBundleIdentifier

    var errorDescription: String? {
        switch self {
        case let .invalidProfile(issues):
            let details = issues.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
            return "The selected profile cannot be used by the tunnel: \(details)"
        case .missingProviderBundleIdentifier:
            return "The packet-tunnel provider identifier is not configured."
        }
    }
}

@MainActor
final class TunnelController: ObservableObject {
    @Published private(set) var observedState: TunnelObservedState = .unavailable("VPN preferences have not been loaded yet.")
    @Published private(set) var isPreparing = false

    let providerBundleIdentifier: String

    private var manager: NETunnelProviderManager?
    nonisolated(unsafe) private var statusObserver: NSObjectProtocol?

    init(providerBundleIdentifier: String = "dev.tunguska.macos.TunguskaTunnel") {
        self.providerBundleIdentifier = providerBundleIdentifier
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    var statusImageName: String {
        switch observedState {
        case .connected: "lock.fill"
        case .connecting, .disconnecting: "lock.open.rotation"
        case .failed: "exclamationmark.triangle.fill"
        case .disconnected, .unavailable: "lock.open"
        }
    }

    var canStart: Bool {
        manager != nil && !isPreparing
    }

    func refresh() {
        isPreparing = true
        Task {
            do {
                let managers = try await loadManagers()
                guard let manager = managers.first?.manager else {
                    self.manager = nil
                    observedState = .unavailable("No saved VPN configuration was found. Start will create one locally.")
                    isPreparing = false
                    return
                }
                self.manager = manager
                observe(manager)
                updateState(manager.connection.status)
                isPreparing = false
            } catch {
                manager = nil
                observedState = .failed(error.localizedDescription)
                isPreparing = false
            }
        }
    }

    func connect(profile: ProfileIr) async throws {
        let issues = profile.validationIssues()
        guard issues.isEmpty else {
            throw TunnelControllerError.invalidProfile(issues)
        }
        guard !providerBundleIdentifier.isEmpty else {
            throw TunnelControllerError.missingProviderBundleIdentifier
        }

        isPreparing = true
        do {
            let manager = try await ensureManager(for: profile)
            self.manager = manager
            observe(manager)
            try manager.connection.startVPNTunnel()
            updateState(manager.connection.status)
            isPreparing = false
        } catch {
            isPreparing = false
            observedState = .failed(error.localizedDescription)
            throw error
        }
    }

    func disconnect() async throws {
        guard let manager else {
            observedState = .disconnected
            return
        }
        manager.connection.stopVPNTunnel()
        updateState(manager.connection.status)
    }

    private func ensureManager(for profile: ProfileIr) async throws -> NETunnelProviderManager {
        let managers = try await loadManagers()
        let manager = managers.first?.manager ?? NETunnelProviderManager()
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.serverAddress = profile.endpointSummary
        // The provider receives only the Keychain profile identifier and public endpoint summary.
        // REALITY secrets stay in the Keychain-backed profile store and are resolved by the tunnel runtime.
        protocolConfiguration.providerConfiguration = [
            "profileID": profile.id,
            "serverAddress": profile.endpointSummary,
        ]
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "Tunguska VPN"
        manager.isEnabled = true

        try await saveManager(manager)
        try await loadManager(manager)
        return manager
    }

    private func loadManagers() async throws -> [TunnelManagerReference] {
        try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (managers ?? []).map(TunnelManagerReference.init))
                }
            }
        }
    }

    private func saveManager(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func loadManager(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func observe(_ manager: NETunnelProviderManager) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] _ in
            let status = manager.connection.status
            Task { @MainActor [weak self] in
                guard let self else { return }
                updateState(status)
            }
        }
    }

    private func updateState(_ status: NEVPNStatus) {
        switch status {
        case .invalid:
            observedState = .unavailable("The saved VPN configuration is not ready.")
        case .disconnected:
            observedState = .disconnected
        case .connecting:
            observedState = .connecting
        case .connected:
            observedState = .connected
        case .reasserting:
            observedState = .connecting
        case .disconnecting:
            observedState = .disconnecting
        @unknown default:
            observedState = .failed("NetworkExtension reported an unknown state.")
        }
    }
}

private struct TunnelManagerReference: @unchecked Sendable {
    let manager: NETunnelProviderManager

    init(_ manager: NETunnelProviderManager) {
        self.manager = manager
    }
}
