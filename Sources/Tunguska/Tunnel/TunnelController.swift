import Foundation
import os
import TunguskaCore

enum TunnelObservedState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed(String)
    case unavailable(String)

    func title(language: AppLanguage) -> String {
        switch self {
        case .disconnected: L10n.t(L10n.Key.stateDisconnected, language: language)
        case .connecting: L10n.t(L10n.Key.stateConnecting, language: language)
        case .connected: L10n.t(L10n.Key.stateConnected, language: language)
        case .disconnecting: L10n.t(L10n.Key.stateDisconnecting, language: language)
        case .failed: L10n.t(L10n.Key.stateFailed, language: language)
        case .unavailable: L10n.t(L10n.Key.stateUnavailable, language: language)
        }
    }

    func detail(language: AppLanguage) -> String {
        switch self {
        case .disconnected:
            L10n.t(L10n.Key.stateDisconnectedDetail, language: language)
        case .connecting:
            L10n.t(L10n.Key.stateConnectingDetail, language: language)
        case .connected:
            L10n.t(L10n.Key.stateConnectedDetail, language: language)
        case .disconnecting:
            L10n.t(L10n.Key.stateDisconnectingDetail, language: language)
        case let .failed(message):
            message
        case let .unavailable(message):
            message
        }
    }

    /// Title in the currently active UI language.
    @MainActor var title: String { title(language: AppSettings.shared.appLanguage) }

    /// Detail in the currently active UI language.
    @MainActor var detail: String { detail(language: AppSettings.shared.appLanguage) }
}

enum TunnelControllerError: LocalizedError {
    case invalidProfile([ValidationIssue])
    case configurationFailed(String)
    case startFailed(String)
    case stopFailed(String)

    /// These errors surface only from MainActor UI/model code; the lookup of
    /// the active language is safe to perform under `assumeIsolated`.
    nonisolated var errorDescription: String? {
        MainActor.assumeIsolated {
            switch self {
            case let .invalidProfile(issues):
                let details = issues.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
                return L10n.fmt(L10n.Key.errorInvalidProfileFormat, details)
            case let .configurationFailed(message),
                 let .startFailed(message),
                 let .stopFailed(message):
                return message
            }
        }
    }
}

@MainActor
final class TunnelController: ObservableObject {
    private static let logger = Logger(subsystem: "dev.tunguska.macos", category: "tunnel")

    @Published private(set) var observedState: TunnelObservedState = .unavailable(L10n.t(L10n.Key.errorServiceNotChecked))
    @Published private(set) var isPreparing = false
    @Published private(set) var connectedInterface: String?
    @Published private(set) var activeMode: HelperCommandMode = .tun

    let traffic = TrafficMonitor()

    private let client = HelperClient()

    var statusImageName: String {
        switch observedState {
        case .connected: "lock.fill"
        case .connecting, .disconnecting: "lock.open.rotation"
        case .failed: "exclamationmark.triangle.fill"
        case .disconnected, .unavailable: "lock.open"
        }
    }

    var canStart: Bool {
        !isPreparing
    }

    func refresh() {
        isPreparing = true
        Task {
            do {
                let response = try await client.send(.status())
                await apply(response)
            } catch {
                observedState = .unavailable(error.localizedDescription)
            }
            isPreparing = false
        }
    }

    func connect(profile: ProfileIr, mode: HelperCommandMode = .tun) async throws {
        Self.logger.log("connect requested for profile \(profile.name, privacy: .public) mode=\(mode.rawValue, privacy: .public)")
        let issues = profile.validationIssues()
        guard issues.isEmpty else {
            Self.logger.error("profile validation failed: \(issues.map(\.field), privacy: .public)")
            throw TunnelControllerError.invalidProfile(issues)
        }

        let generated: SingBoxGeneratedConfiguration
        do {
            generated = try SingBoxConfigurationBuilder.build(profile: profile, mode: mode)
        } catch {
            Self.logger.error("configuration build failed: \(error.localizedDescription, privacy: .public)")
            throw TunnelControllerError.configurationFailed(error.localizedDescription)
        }

        isPreparing = true
        defer { isPreparing = false }

        let response: HelperResponse
        do {
            response = try await client.send(
                .start(
                    profileID: profile.id,
                    config: generated.json,
                    mode: mode,
                    expectedInterfaceAddress: mode == .tun ? HelperProtocol.defaultTunAddress : nil
                )
            )
        } catch {
            Self.logger.error("helper start request failed: \(error.localizedDescription, privacy: .public)")
            observedState = .unavailable(error.localizedDescription)
            throw error
        }

        Self.logger.log(
            "helper start responded ok=\(response.ok, privacy: .public) state=\(response.status?.state.rawValue ?? "nil", privacy: .public) interface=\(response.status?.interface ?? "nil", privacy: .public)"
        )
        await apply(response)

        guard response.ok else {
            let message = response.message ?? L10n.t(L10n.Key.errorHelperStartFailed)
            observedState = .failed(message)
            throw TunnelControllerError.startFailed(message)
        }

        guard response.status?.state == .running else {
            let message = response.message ?? L10n.t(L10n.Key.errorNoLiveSession)
            observedState = .failed(message)
            throw TunnelControllerError.startFailed(message)
        }

        if mode == .tun {
            guard response.status?.interface != nil else {
                let message = response.message ?? L10n.t(L10n.Key.errorNoTunInterface)
                observedState = .failed(message)
                throw TunnelControllerError.startFailed(message)
            }
        }
    }

    func disconnect() async throws {
        Self.logger.log("disconnect requested")
        isPreparing = true
        defer { isPreparing = false }
        observedState = .disconnecting

        let response: HelperResponse
        do {
            response = try await client.send(.stop())
        } catch {
            Self.logger.error("helper stop request failed: \(error.localizedDescription, privacy: .public)")
            observedState = .failed(error.localizedDescription)
            throw error
        }

        guard response.ok else {
            let message = response.message ?? L10n.t(L10n.Key.errorHelperStopFailed)
            Self.logger.error("helper stop rejected: \(message, privacy: .public)")
            observedState = .failed(message)
            throw TunnelControllerError.stopFailed(message)
        }
        traffic.stop()
        observedState = .disconnected
    }

    private func apply(_ response: HelperResponse) async {
        guard let status = response.status else {
            connectedInterface = nil
            traffic.stop()
            observedState = response.ok ? .disconnected : .failed(response.message ?? L10n.t(L10n.Key.errorIncompleteResponse))
            return
        }

        let mode = status.mode ?? .tun
        activeMode = mode

        switch status.state {
        case .stopped:
            connectedInterface = nil
            traffic.stop()
            observedState = .disconnected
        case .starting:
            observedState = .connecting
        case .running:
            switch mode {
            case .systemProxy:
                // No TUN interface exists in this mode; proxied traffic crosses the
                // loopback mixed inbound, so sample lo0 for the live charts.
                connectedInterface = nil
                traffic.start(interface: "lo0")
                observedState = .connected
            case .tun:
                if let reported = status.interface {
                    let interface = await TrafficMonitor.resolveInterface(
                        hint: reported,
                        address: HelperProtocol.defaultTunAddress
                    ) ?? reported
                    if interface != reported {
                        Self.logger.log(
                            "resolved tunnel interface \(interface, privacy: .public) (helper reported '\(reported, privacy: .public)')"
                        )
                    }
                    connectedInterface = interface
                    traffic.start(interface: interface)
                    observedState = .connected
                } else {
                    observedState = .failed(status.message ?? L10n.t(L10n.Key.errorNoTunReported))
                }
            }
        case .failed:
            connectedInterface = nil
            traffic.stop()
            observedState = .failed(status.message ?? L10n.t(L10n.Key.errorServiceFailure))
        }
    }
}
