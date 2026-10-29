import Foundation

public struct SingBoxConfigurationWarning: Equatable, Sendable {
    public let field: String
    public let message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

public struct SingBoxGeneratedConfiguration: Equatable, Sendable {
    public let json: String
    public let warnings: [SingBoxConfigurationWarning]

    public init(json: String, warnings: [SingBoxConfigurationWarning]) {
        self.json = json
        self.warnings = warnings
    }
}

public enum SingBoxConfigurationError: LocalizedError {
    case invalidProfile([ValidationIssue])
    case serializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidProfile(issues):
            let details = issues.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
            return "The profile cannot be converted into a sing-box configuration: \(details)"
        case let .serializationFailed(message):
            return "The sing-box configuration could not be serialized: \(message)"
        }
    }
}

/// Builds the configuration consumed by libbox inside the NetworkExtension.
///
/// The output deliberately avoids runtime-downloaded geosite/geoip databases. Criteria that
/// require those datasets are reported as warnings instead of being silently treated as
/// matched. On macOS a packet-tunnel extension also cannot enforce Android package filters.
public enum SingBoxConfigurationBuilder {
    public static let proxyTag = "proxy"
    public static let directTag = "direct"
    public static let blockTag = "block"
    public static let tunTag = "tun-in"
    public static let mixedTag = "mixed-in"
    public static let localDNSTag = "dns-local"

    public static func build(
        profile: ProfileIr,
        mode: HelperCommandMode = .tun
    ) throws -> SingBoxGeneratedConfiguration {
        let issues = profile.validationIssues()
        guard issues.isEmpty else {
            throw SingBoxConfigurationError.invalidProfile(issues)
        }

        var warnings: [SingBoxConfigurationWarning] = []
        let effective = try EffectiveRoutingPolicyResolver.resolve(profile)

        let dns = makeDNS(profile.dns, warnings: &warnings)
        let rules = makeRules(effective.rules, warnings: &warnings)

        let configuration: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
            ],
            "dns": dns,
            "inbounds": makeInbounds(mode: mode),
            "outbounds": [
                makeOutbound(profile.outbound),
                ["type": "direct", "tag": directTag],
                ["type": "block", "tag": blockTag],
            ],
            "route": [
                "rules": rules,
                "final": outboundTag(for: profile.routing.defaultAction),
                "auto_detect_interface": true,
                "default_domain_resolver": ["server": localDNSTag],
            ],
            "experimental": [
                "cache_file": ["enabled": true],
            ],
        ]

        guard JSONSerialization.isValidJSONObject(configuration) else {
            throw SingBoxConfigurationError.serializationFailed("Configuration contains unsupported values.")
        }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: configuration,
                options: [.sortedKeys, .prettyPrinted]
            )
            guard let json = String(data: data, encoding: .utf8) else {
                throw SingBoxConfigurationError.serializationFailed("Configuration is not valid UTF-8.")
            }
            return SingBoxGeneratedConfiguration(json: json, warnings: warnings)
        } catch let error as SingBoxConfigurationError {
            throw error
        } catch {
            throw SingBoxConfigurationError.serializationFailed(error.localizedDescription)
        }
    }

    /// TUN mode owns the routing table via a virtual interface; system-proxy mode only
    /// exposes a loopback mixed (HTTP + SOCKS) inbound that the helper registers with
    /// macOS as the system proxy, the way Clash Verge's sysproxy flow works.
    private static func makeInbounds(mode: HelperCommandMode) -> [[String: Any]] {
        switch mode {
        case .tun:
            return [
                [
                    "type": "tun",
                    "tag": tunTag,
                    "address": ["172.19.0.1/30"],
                    "mtu": 9000,
                    "auto_route": true,
                    "strict_route": false,
                    "stack": "system",
                ],
            ]
        case .systemProxy:
            return [
                [
                    "type": "mixed",
                    "tag": mixedTag,
                    "listen": HelperProtocol.proxyListenHost,
                    "listen_port": HelperProtocol.defaultProxyPort,
                ],
            ]
        }
    }

    private static func makeOutbound(_ outbound: VlessRealityOutbound) -> [String: Any] {
        let tls: [String: Any] = [
            "enabled": true,
            "server_name": outbound.serverName,
            "utls": [
                "enabled": true,
                "fingerprint": outbound.utlsFingerprint,
            ],
            "reality": [
                "enabled": true,
                "public_key": outbound.realityPublicKey,
                "short_id": outbound.realityShortId,
            ],
        ]
        // realitySpiderX is retained for share-URI parity; sing-box derives the REALITY
        // handshake path from the destination and does not consume this value.

        var result: [String: Any] = [
            "type": "vless",
            "tag": proxyTag,
            "server": outbound.address,
            "server_port": outbound.port,
            "uuid": outbound.uuid,
            "tls": tls,
        ]
        if let flow = outbound.flow {
            result["flow"] = flow
        }
        return result
    }

    private static func makeRules(
        _ rules: [RouteRule],
        warnings: inout [SingBoxConfigurationWarning]
    ) -> [[String: Any]] {
        rules.compactMap { rule in
            var entry: [String: Any] = [:]
            if !rule.match.domainExact.isEmpty {
                entry["domain"] = rule.match.domainExact
            }
            if !rule.match.domainSuffix.isEmpty {
                entry["domain_suffix"] = rule.match.domainSuffix
            }
            if !rule.match.domainKeyword.isEmpty {
                entry["domain_keyword"] = rule.match.domainKeyword
            }
            if !rule.match.ipCidrs.isEmpty {
                entry["ip_cidr"] = rule.match.ipCidrs
            }
            if !rule.match.ports.isEmpty {
                entry["port"] = rule.match.ports
            }
            if !rule.match.protocols.isEmpty {
                entry["network"] = rule.match.protocols.map { $0.rawValue.lowercased() }
            }

            if !rule.match.geoSites.isEmpty {
                warnings.append(.init(
                    field: "routing.rules.\(rule.id).geoSites",
                    message: "Geosite criteria are not bundled with the runtime and were omitted from this rule."
                ))
            }
            if !rule.match.geoIps.isEmpty {
                warnings.append(.init(
                    field: "routing.rules.\(rule.id).geoIps",
                    message: "GeoIP criteria are not bundled with the runtime and were omitted from this rule."
                ))
            }
            if !rule.match.asns.isEmpty {
                warnings.append(.init(
                    field: "routing.rules.\(rule.id).asns",
                    message: "ASN criteria are not supported without a downloaded rule set and were omitted from this rule."
                ))
            }
            if !rule.match.packageNames.isEmpty {
                warnings.append(.init(
                    field: "routing.rules.\(rule.id).packageNames",
                    message: "Application package filters cannot be evaluated by a macOS packet-tunnel extension and were omitted from this rule."
                ))
            }

            switch rule.action {
            case .block:
                entry["action"] = "reject"
            case .proxy, .direct:
                entry["action"] = "route"
                entry["outbound"] = outboundTag(for: rule.action)
            }

            let hasMatcher = entry.keys.contains {
                !["action", "outbound"].contains($0)
            }
            guard hasMatcher else {
                warnings.append(.init(
                    field: "routing.rules.\(rule.id)",
                    message: "Rule has no criteria supported by the macOS runtime and was omitted."
                ))
                return nil
            }
            return entry
        }
    }

    private static func outboundTag(for action: RouteAction) -> String {
        switch action {
        case .proxy: proxyTag
        case .direct: directTag
        case .block: blockTag
        }
    }

    private static func makeDNS(
        _ mode: DnsMode,
        warnings: inout [SingBoxConfigurationWarning]
    ) -> [String: Any] {
        var servers: [[String: Any]] = [
            ["type": "local", "tag": localDNSTag],
        ]

        switch mode {
        case .systemDns:
            return [
                "servers": servers,
                "final": localDNSTag,
                "strategy": "prefer_ipv4",
            ]

        case let .vpnDns(endpoints), let .customEncrypted(_, endpoints):
            let encryptedKind: EncryptedDnsKind? = {
                if case let .customEncrypted(kind, _) = mode { return kind }
                return nil
            }()
            var remoteTags: [String] = []
            for (index, endpoint) in endpoints.enumerated() {
                guard let server = encryptedDNSServer(
                    endpoint,
                    kind: encryptedKind,
                    tag: "dns-remote-\(index)",
                    warnings: &warnings
                ) else {
                    continue
                }
                servers.append(server)
                remoteTags.append("dns-remote-\(index)")
            }

            guard let final = remoteTags.first else {
                warnings.append(.init(
                    field: "dns",
                    message: "No usable encrypted DNS endpoint was found; falling back to the system DNS resolver."
                ))
                return [
                    "servers": servers,
                    "final": localDNSTag,
                    "strategy": "prefer_ipv4",
                ]
            }
            return [
                "servers": servers,
                "final": final,
                "strategy": "prefer_ipv4",
            ]
        }
    }

    private static func encryptedDNSServer(
        _ endpoint: String,
        kind: EncryptedDnsKind?,
        tag: String,
        warnings: inout [SingBoxConfigurationWarning]
    ) -> [String: Any]? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("https://") {
            guard let components = URLComponents(string: trimmed),
                  let host = components.host,
                  !host.isEmpty else {
                warnings.append(.init(field: "dns", message: "Invalid DoH endpoint '\(endpoint)' was ignored."))
                return nil
            }
            var tls: [String: Any] = ["enabled": true]
            if host.rangeOfCharacter(from: CharacterSet.letters) != nil {
                tls["server_name"] = host
            }
            var server: [String: Any] = [
                "type": "https",
                "tag": tag,
                "server": host,
                "detour": proxyTag,
                "tls": tls,
            ]
            if let port = components.port {
                server["server_port"] = port
            }
            server["path"] = components.path.isEmpty ? "/dns-query" : components.path
            if let query = components.percentEncodedQuery {
                server["path"] = (server["path"] as? String ?? "/dns-query") + "?" + query
            }
            return server
        }

        if trimmed.lowercased().hasPrefix("tls://") || kind == .dot {
            let value = trimmed.replacingOccurrences(of: "tls://", with: "", options: [.caseInsensitive])
            let hostPort = value.split(separator: ":", maxSplits: 1).map(String.init)
            guard let host = hostPort.first, !host.isEmpty else {
                warnings.append(.init(field: "dns", message: "Invalid DoT endpoint '\(endpoint)' was ignored."))
                return nil
            }
            var tls: [String: Any] = ["enabled": true]
            if host.rangeOfCharacter(from: CharacterSet.letters) != nil {
                tls["server_name"] = host
            }
            var server: [String: Any] = [
                "type": "tls",
                "tag": tag,
                "server": host,
                "detour": proxyTag,
                "tls": tls,
            ]
            if hostPort.count == 2, let port = Int(hostPort[1]), (1 ... 65_535).contains(port) {
                server["server_port"] = port
            }
            return server
        }

        warnings.append(.init(
            field: "dns",
            message: "Unsupported encrypted DNS endpoint '\(endpoint)' was ignored; use an https:// or tls:// URL."
        ))
        return nil
    }
}
