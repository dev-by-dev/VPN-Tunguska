import Foundation
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
    @Published private(set) var observedState: TunnelObservedState = .unavailable("The privileged tunnel service has not been checked yet.")
    @Published private(set) var isPreparing = false

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
                apply(response)
            } catch {
                observedState = .unavailable(error.localizedDescription)
            }
            isPreparing = false
        }
    }

    func connect(profile: ProfileIr) async throws {
        let issues = profile.validationIssues()
        guard issues.isEmpty else {
            throw TunnelControllerError.invalidProfile(issues)
        }

        let generated: SingBoxGeneratedConfiguration
        do {
            generated = try SingBoxConfigurationBuilder.build(profile: profile)
        } catch {
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
            observedState = .unavailable(error.localizedDescription)
            throw error
        }

        apply(response)

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
        isPreparing = true
        defer { isPreparing = false }
        observedState = .disconnecting

        let response: HelperResponse
        do {
            response = try await client.send(.stop())
        } catch {
            observedState = .failed(error.localizedDescription)
            throw error
        }

        guard response.ok else {
            let message = response.message ?? "The privileged tunnel service could not stop sing-box."
            observedState = .failed(message)
            throw TunnelControllerError.stopFailed(message)
        }
        observedState = .disconnected
    }

    private func apply(_ response: HelperResponse) {
        guard let status = response.status else {
            observedState = response.ok ? .disconnected : .failed(response.message ?? "The helper response was incomplete.")
            return
        }

        switch status.state {
        case .stopped:
            observedState = .disconnected
        case .starting:
            observedState = .connecting
        case .running:
            if status.interface != nil {
                observedState = .connected
            } else {
                observedState = .failed(status.message ?? "The helper reported a running engine without a TUN interface.")
            }
        case .failed:
            observedState = .failed(status.message ?? "The tunnel service reported a failure.")
        }
    }
}
