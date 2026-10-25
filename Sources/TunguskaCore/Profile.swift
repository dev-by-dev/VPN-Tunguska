import Foundation

public let requiredVLESSFlow = "xtls-rprx-vision"
public let defaultRealitySpiderX = "/"

public struct ValidationIssue: Equatable, Sendable {
    public let field: String
    public let message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

public struct ProfileEndpoint: Equatable, Sendable {
    public let address: String
    public let port: Int
    public let serverName: String

    public init(address: String, port: Int, serverName: String) {
        self.address = address
        self.port = port
        self.serverName = serverName
    }
}

public struct VlessRealityOutbound: Codable, Equatable, Sendable {
    public var address: String
    public var port: Int
    public var uuid: String
    public var serverName: String
    public var realityPublicKey: String
    public var realityShortId: String
    public var realitySpiderX: String?
    public var flow: String?
    public var utlsFingerprint: String

    public init(
        address: String,
        port: Int,
        uuid: String,
        serverName: String,
        realityPublicKey: String,
        realityShortId: String,
        realitySpiderX: String? = nil,
        flow: String? = nil,
        utlsFingerprint: String = "chrome"
    ) {
        self.address = address
        self.port = port
        self.uuid = uuid
        self.serverName = serverName
        self.realityPublicKey = realityPublicKey
        self.realityShortId = realityShortId
        self.realitySpiderX = realitySpiderX
        self.flow = flow
        self.utlsFingerprint = utlsFingerprint
    }

    public var effectiveRealitySpiderX: String {
        realitySpiderX ?? defaultRealitySpiderX
    }

    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "outbound.address", message: "Server address must not be blank."))
        }
        if !(1 ... 65_535).contains(port) {
            issues.append(.init(field: "outbound.port", message: "Port must be between 1 and 65535."))
        }
        if uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "outbound.uuid", message: "UUID must not be blank."))
        }
        if serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "outbound.serverName", message: "Server name must not be blank."))
        }
        if realityPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "outbound.realityPublicKey", message: "REALITY public key must not be blank."))
        }
        if realityShortId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "outbound.realityShortId", message: "REALITY short id must not be blank."))
        }
        if let realitySpiderX, realitySpiderX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "outbound.realitySpiderX", message: "REALITY spider path must not be blank when provided."))
        }
        if let flow, flow != requiredVLESSFlow {
            issues.append(.init(field: "outbound.flow", message: "Only \(requiredVLESSFlow) is accepted."))
        }
        return issues
    }

    private enum CodingKeys: String, CodingKey {
        case address, port, uuid, serverName, realityPublicKey, realityShortId
        case realitySpiderX, flow, utlsFingerprint
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        address = try values.decode(String.self, forKey: .address)
        port = try values.decode(Int.self, forKey: .port)
        uuid = try values.decode(String.self, forKey: .uuid)
        serverName = try values.decode(String.self, forKey: .serverName)
        realityPublicKey = try values.decode(String.self, forKey: .realityPublicKey)
        realityShortId = try values.decode(String.self, forKey: .realityShortId)
        realitySpiderX = try values.decodeIfPresent(String.self, forKey: .realitySpiderX)
        flow = try values.decodeIfPresent(String.self, forKey: .flow)
        utlsFingerprint = try values.decodeIfPresent(String.self, forKey: .utlsFingerprint) ?? "chrome"
    }
}

public enum SplitTunnelMode: Equatable, Sendable {
    case fullTunnel
    case allowlist(packageNames: [String])
    case denylist(packageNames: [String])

    public var packageNames: [String] {
        switch self {
        case .fullTunnel: []
        case let .allowlist(packageNames), let .denylist(packageNames): packageNames
        }
    }

    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (index, packageName) in packageNames.enumerated() where packageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "vpn.splitTunnel.packageNames[\(index)]", message: "Application identifier must not be blank."))
        }
        let duplicates = Dictionary(grouping: packageNames, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        for duplicate in duplicates {
            issues.append(.init(field: "vpn.splitTunnel.packageNames", message: "Duplicate application identifier '\(duplicate)'."))
        }
        return issues
    }
}

extension SplitTunnelMode: Codable {
    private enum CodingKeys: String, CodingKey { case kind, packageNames }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(String.self, forKey: .kind) {
        case "full_tunnel":
            self = .fullTunnel
        case "allowlist":
            self = .allowlist(packageNames: try values.decode([String].self, forKey: .packageNames))
        case "denylist":
            self = .denylist(packageNames: try values.decode([String].self, forKey: .packageNames))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: values, debugDescription: "Unsupported split tunnel mode.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fullTunnel:
            try values.encode("full_tunnel", forKey: .kind)
        case let .allowlist(packageNames):
            try values.encode("allowlist", forKey: .kind)
            try values.encode(packageNames, forKey: .packageNames)
        case let .denylist(packageNames):
            try values.encode("denylist", forKey: .kind)
            try values.encode(packageNames, forKey: .packageNames)
        }
    }
}

public struct VpnPolicy: Codable, Equatable, Sendable {
    public var splitTunnel: SplitTunnelMode

    public init(splitTunnel: SplitTunnelMode = .fullTunnel) {
        self.splitTunnel = splitTunnel
    }

    public func validationIssues() -> [ValidationIssue] {
        splitTunnel.validationIssues()
    }

    private enum CodingKeys: String, CodingKey { case splitTunnel }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        splitTunnel = try values.decodeIfPresent(SplitTunnelMode.self, forKey: .splitTunnel) ?? .fullTunnel
    }
}

public enum EncryptedDnsKind: String, Codable, Equatable, Sendable {
    case doh = "DOH"
    case dot = "DOT"
}

public enum DnsMode: Equatable, Sendable {
    case vpnDns(servers: [String])
    case systemDns
    case customEncrypted(kind: EncryptedDnsKind, endpoints: [String])

    public func validationIssues() -> [ValidationIssue] {
        let values: [String]
        let field: String
        switch self {
        case let .vpnDns(servers):
            values = servers
            field = "dns.servers"
        case .systemDns:
            return []
        case let .customEncrypted(_, endpoints):
            values = endpoints
            field = "dns.endpoints"
        }

        var issues = values.enumerated().compactMap { index, value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ValidationIssue(field: "\(field)[\(index)]", message: "Value must not be blank.")
                : nil
        }
        if case let .customEncrypted(_, endpoints) = self, endpoints.isEmpty {
            issues.append(.init(field: "dns.endpoints", message: "Custom encrypted DNS requires at least one endpoint."))
        }
        return issues
    }
}

extension DnsMode: Codable {
    private enum CodingKeys: String, CodingKey { case kind, servers, encryptedKind, endpoints }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(String.self, forKey: .kind) {
        case "vpn_dns":
            self = .vpnDns(servers: try values.decodeIfPresent([String].self, forKey: .servers) ?? [
                "https://1.1.1.1/dns-query",
                "https://1.0.0.1/dns-query",
            ])
        case "system_dns":
            self = .systemDns
        case "custom_encrypted":
            self = .customEncrypted(
                kind: try values.decode(EncryptedDnsKind.self, forKey: .encryptedKind),
                endpoints: try values.decode([String].self, forKey: .endpoints)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: values, debugDescription: "Unsupported DNS mode.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .vpnDns(servers):
            try values.encode("vpn_dns", forKey: .kind)
            try values.encode(servers, forKey: .servers)
        case .systemDns:
            try values.encode("system_dns", forKey: .kind)
        case let .customEncrypted(kind, endpoints):
            try values.encode("custom_encrypted", forKey: .kind)
            try values.encode(kind, forKey: .encryptedKind)
            try values.encode(endpoints, forKey: .endpoints)
        }
    }
}

public struct SafetySettings: Codable, Equatable, Sendable {
    public var safeMode: Bool
    public var compatibilityLocalProxy: Bool
    public var debugEndpointsEnabled: Bool

    public init(safeMode: Bool = true, compatibilityLocalProxy: Bool = false, debugEndpointsEnabled: Bool = false) {
        self.safeMode = safeMode
        self.compatibilityLocalProxy = compatibilityLocalProxy
        self.debugEndpointsEnabled = debugEndpointsEnabled
    }

    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if safeMode && compatibilityLocalProxy {
            issues.append(.init(field: "safety.compatibilityLocalProxy", message: "Compatibility local proxy cannot be enabled while safe mode is active."))
        }
        if safeMode && debugEndpointsEnabled {
            issues.append(.init(field: "safety.debugEndpointsEnabled", message: "Debug endpoints cannot be enabled while safe mode is active."))
        }
        return issues
    }

    private enum CodingKeys: String, CodingKey { case safeMode, compatibilityLocalProxy, debugEndpointsEnabled }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        safeMode = try values.decodeIfPresent(Bool.self, forKey: .safeMode) ?? true
        compatibilityLocalProxy = try values.decodeIfPresent(Bool.self, forKey: .compatibilityLocalProxy) ?? false
        debugEndpointsEnabled = try values.decodeIfPresent(Bool.self, forKey: .debugEndpointsEnabled) ?? false
    }
}

public struct ProfileIr: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var outbound: VlessRealityOutbound
    public var vpn: VpnPolicy
    public var routing: RoutingPolicy
    public var dns: DnsMode
    public var safety: SafetySettings

    public init(
        id: String,
        name: String,
        outbound: VlessRealityOutbound,
        vpn: VpnPolicy = VpnPolicy(),
        routing: RoutingPolicy = RoutingPolicy(),
        dns: DnsMode = .systemDns,
        safety: SafetySettings = SafetySettings()
    ) {
        self.id = id
        self.name = name
        self.outbound = outbound
        self.vpn = vpn
        self.routing = routing
        self.dns = dns
        self.safety = safety
    }

    public var primaryEndpoint: ProfileEndpoint {
        .init(address: outbound.address, port: outbound.port, serverName: outbound.serverName)
    }

    public var endpointSummary: String {
        "\(outbound.address):\(outbound.port)"
    }

    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "id", message: "Profile id must not be blank."))
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "name", message: "Profile name must not be blank."))
        }
        issues.append(contentsOf: outbound.validationIssues())
        issues.append(contentsOf: vpn.validationIssues())
        issues.append(contentsOf: routing.validationIssues())
        issues.append(contentsOf: dns.validationIssues())
        issues.append(contentsOf: safety.validationIssues())
        return issues
    }

    private enum CodingKeys: String, CodingKey { case id, name, outbound, vpn, routing, dns, safety }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        outbound = try values.decode(VlessRealityOutbound.self, forKey: .outbound)
        vpn = try values.decodeIfPresent(VpnPolicy.self, forKey: .vpn) ?? VpnPolicy()
        routing = try values.decodeIfPresent(RoutingPolicy.self, forKey: .routing) ?? RoutingPolicy()
        dns = try values.decodeIfPresent(DnsMode.self, forKey: .dns) ?? .systemDns
        safety = try values.decodeIfPresent(SafetySettings.self, forKey: .safety) ?? SafetySettings()
    }
}
