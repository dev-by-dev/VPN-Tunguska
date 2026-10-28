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
            "No privileged TUN session is active."
        case .connecting:
            "The sing-box service is starting; the UI remains non-connected until a TUN interface is observed."
        case .connected:
            "The privileged sing-box service reported a live TUN interface."
        case .disconnecting:
            "The privileged service is stopping the tunnel."
        case let .failed(message):
            message
        case let .unavailable(message):
            message
        }
    }
}

enum TunnelControllerError: LocalizedError {
    case invalidProfile([ValidationIssue])
    case configurationFailed(String)
    case startFailed(String)
    case stopFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidProfile(issues):
            let details = issues.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
            return "The selected profile cannot be used by the tunnel: \(details)"
        case let .configurationFailed(message),
             let .startFailed(message),
             let .stopFailed(message):
            return message
        }
    }
}

@MainActor
final class TunnelController: ObservableObject {
    private static let logger = Logger(subsystem: "dev.tunguska.macos", category: "tunnel")

    @Published private(set) var observedState: TunnelObservedState = .unavailable("The privileged tunnel service has not been checked yet.")
    @Published private(set) var isPreparing = false
    @Published private(set) var connectedInterface: String?

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

    func connect(profile: ProfileIr) async throws {
        Self.logger.log("connect requested for profile \(profile.name, privacy: .public)")
        let issues = profile.validationIssues()
        guard issues.isEmpty else {
            Self.logger.error("profile validation failed: \(issues.map(\.field), privacy: .public)")
            throw TunnelControllerError.invalidProfile(issues)
        }

        let generated: SingBoxGeneratedConfiguration
        do {
            generated = try SingBoxConfigurationBuilder.build(profile: profile)
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
                    expectedInterfaceAddress: HelperProtocol.defaultTunAddress
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
            let message = response.message ?? "The privileged tunnel service could not start sing-box."
            observedState = .failed(message)
            throw TunnelControllerError.startFailed(message)
        }

        guard response.status?.state == .running, response.status?.interface != nil else {
            let message = response.message ?? "sing-box did not report a live TUN interface."
            observedState = .failed(message)
            throw TunnelControllerError.startFailed(message)
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
            let message = response.message ?? "The privileged tunnel service could not stop sing-box."
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
            observedState = response.ok ? .disconnected : .failed(response.message ?? "The helper response was incomplete.")
            return
        }

        switch status.state {
        case .stopped:
            connectedInterface = nil
            traffic.stop()
            observedState = .disconnected
        case .starting:
            observedState = .connecting
        case .running:
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
                observedState = .failed(status.message ?? "The helper reported a running engine without a TUN interface.")
            }
        case .failed:
            connectedInterface = nil
            traffic.stop()
            observedState = .failed(status.message ?? "The tunnel service reported a failure.")
        }
    }
}
