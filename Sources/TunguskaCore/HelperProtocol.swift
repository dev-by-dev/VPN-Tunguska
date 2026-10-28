import Foundation

public enum HelperCommandAction: String, Codable, Equatable, Sendable {
    case status
    case start
    case stop
}

public struct HelperRequest: Codable, Equatable, Sendable {
    public var action: HelperCommandAction
    public var profileID: String?
    public var config: String?
    public var expectedInterfaceAddress: String?

    public init(
        action: HelperCommandAction,
        profileID: String? = nil,
        config: String? = nil,
        expectedInterfaceAddress: String? = nil
    ) {
        self.action = action
        self.profileID = profileID
        self.config = config
        self.expectedInterfaceAddress = expectedInterfaceAddress
    }

    public static func status() -> HelperRequest {
        HelperRequest(action: .status)
    }

    public static func start(
        profileID: String,
        config: String,
        expectedInterfaceAddress: String = HelperProtocol.defaultTunAddress
    ) -> HelperRequest {
        HelperRequest(
            action: .start,
            profileID: profileID,
            config: config,
            expectedInterfaceAddress: expectedInterfaceAddress
        )
    }

    public static func stop() -> HelperRequest {
        HelperRequest(action: .stop)
    }
}

public enum HelperRunState: String, Codable, Equatable, Sendable {
    case stopped
    case starting
    case running
    case failed
}

public struct HelperStatus: Codable, Equatable, Sendable {
    public var state: HelperRunState
    public var pid: Int?
    public var interface: String?
    public var startedAt: Date?
    public var message: String?

    public init(
        state: HelperRunState,
        pid: Int? = nil,
        interface: String? = nil,
        startedAt: Date? = nil,
        message: String? = nil
    ) {
        self.state = state
        self.pid = pid
        self.interface = interface
        self.startedAt = startedAt
        self.message = message
    }
}

public struct HelperResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var status: HelperStatus?
    public var message: String?

    public init(ok: Bool, status: HelperStatus? = nil, message: String? = nil) {
        self.ok = ok
        self.status = status
        self.message = message
    }
}

public enum HelperProtocolError: LocalizedError, Equatable {
    case invalidRequest(String)
    case invalidResponse(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidRequest(message),
             let .invalidResponse(message),
             let .invalidConfiguration(message):
            return message
        }
    }
}

public enum HelperProtocol {
    public static let socketPath = "/var/run/tunguska-helper.sock"
    public static let defaultTunAddress = "172.19.0.1"

    private static let requestEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    private static let responseDecoder = JSONDecoder()

    public static func encode(_ request: HelperRequest) throws -> Data {
        do {
            return try requestEncoder.encode(request)
        } catch {
            throw HelperProtocolError.invalidRequest("Could not encode helper request: \(error.localizedDescription)")
        }
    }

    public static func decodeRequest(_ data: Data) throws -> HelperRequest {
        do {
            return try responseDecoder.decode(HelperRequest.self, from: data)
        } catch {
            throw HelperProtocolError.invalidRequest("Could not decode helper request JSON.")
        }
    }

    public static func encode(_ response: HelperResponse) throws -> Data {
        do {
            return try requestEncoder.encode(response)
        } catch {
            throw HelperProtocolError.invalidResponse("Could not encode helper response.")
        }
    }

    public static func decodeResponse(_ data: Data) throws -> HelperResponse {
        do {
            return try responseDecoder.decode(HelperResponse.self, from: data)
        } catch {
            throw HelperProtocolError.invalidResponse("Could not decode helper response JSON.")
        }
    }

    /// Accept only Tunguska-shaped sing-box documents. This prevents the privileged helper
    /// from being turned into a generic launcher for arbitrary network processes.
    public static func validateStartConfiguration(_ config: String) throws {
        guard let data = config.data(using: .utf8) else {
            throw HelperProtocolError.invalidConfiguration("The tunnel configuration is not valid UTF-8.")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw HelperProtocolError.invalidConfiguration("The tunnel configuration is not valid JSON.")
        }

        guard let root = object as? [String: Any] else {
            throw HelperProtocolError.invalidConfiguration("The tunnel configuration must be a JSON object.")
        }
        guard let inbounds = root["inbounds"] as? [[String: Any]], !inbounds.isEmpty else {
            throw HelperProtocolError.invalidConfiguration("The tunnel configuration must contain inbounds.")
        }
        guard inbounds.contains(where: { $0["type"] as? String == "tun" }) else {
            throw HelperProtocolError.invalidConfiguration("The tunnel configuration must contain a TUN inbound.")
        }
        guard let outbounds = root["outbounds"] as? [[String: Any]],
              outbounds.contains(where: { $0["type"] as? String == "vless" }),
              outbounds.contains(where: { $0["type"] as? String == "direct" }),
              outbounds.contains(where: { $0["type"] as? String == "block" })
        else {
            throw HelperProtocolError.invalidConfiguration(
                "The tunnel configuration must contain VLESS, direct, and block outbounds."
            )
        }
        guard root["route"] is [String: Any] else {
            throw HelperProtocolError.invalidConfiguration("The tunnel configuration must contain a route section.")
        }
    }
}

public enum HelperInstallation {
    public static let rootDirectory = URL(fileURLWithPath: "/Library/Tunguska", isDirectory: true)
    public static let helperBinary = rootDirectory.appendingPathComponent("TunguskaHelper")
    public static let singBoxBinary = rootDirectory.appendingPathComponent("sing-box")
    public static let runtimeDirectory = rootDirectory.appendingPathComponent("runtime", isDirectory: true)
    public static let logDirectory = rootDirectory.appendingPathComponent("logs", isDirectory: true)
    public static let launchDaemonPlist = URL(
        fileURLWithPath: "/Library/LaunchDaemons/dev.tunguska.macos.helper.plist"
    )
}
