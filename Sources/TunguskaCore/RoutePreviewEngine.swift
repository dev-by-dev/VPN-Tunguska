import Foundation
import Network

public struct RoutePreviewRequest: Equatable, Sendable {
    public var packageName: String?
    public var destinationHost: String?
    public var destinationIp: String?
    public var destinationPort: Int?
    public var `protocol`: NetworkProtocol?

    public init(
        packageName: String? = nil,
        destinationHost: String? = nil,
        destinationIp: String? = nil,
        destinationPort: Int? = nil,
        protocol: NetworkProtocol? = nil
    ) {
        self.packageName = packageName
        self.destinationHost = destinationHost
        self.destinationIp = destinationIp
        self.destinationPort = destinationPort
        self.`protocol` = `protocol`
    }
}

public struct RoutePreviewOutcome: Equatable, Sendable {
    public let action: RouteAction
    public let matchedRuleId: String?
    public let reason: String
    public let runtimeDatasetHint: String?

    public init(action: RouteAction, matchedRuleId: String?, reason: String, runtimeDatasetHint: String? = nil) {
        self.action = action
        self.matchedRuleId = matchedRuleId
        self.reason = reason
        self.runtimeDatasetHint = runtimeDatasetHint
    }
}

public enum RoutePreviewEngine {
    public static func evaluate(_ profile: ProfileIr, request: RoutePreviewRequest) throws -> RoutePreviewOutcome {
        if isLoopback(host: request.destinationHost, ip: request.destinationIp) {
            return RoutePreviewOutcome(
                action: .direct,
                matchedRuleId: "__loopback__",
                reason: "Loopback traffic always remains local."
            )
        }

        if let outcome = splitTunnelOutcome(profile, packageName: request.packageName) {
            return outcome
        }

        let effectiveRouting = try EffectiveRoutingPolicyResolver.resolve(profile)
        for rule in effectiveRouting.rules where try matches(rule, request: request) {
            let reason: String
            switch rule.id {
            case "__regional_bypass_russia__":
                reason = "Matched regional bypass preset 'Russia'."
            case "__regional_bypass_custom_direct__":
                reason = "Matched a custom direct domain in Regional Bypass."
            default:
                reason = "Matched explicit routing rule '\(rule.id)'."
            }
            return RoutePreviewOutcome(
                action: rule.action,
                matchedRuleId: rule.id,
                reason: reason
            )
        }

        return RoutePreviewOutcome(
            action: profile.routing.defaultAction,
            matchedRuleId: nil,
            reason: "No explicit rule matched; using routing default.",
            runtimeDatasetHint: runtimeDatasetHint(profile, request: request)
        )
    }

    private static func splitTunnelOutcome(_ profile: ProfileIr, packageName: String?) -> RoutePreviewOutcome? {
        switch profile.vpn.splitTunnel {
        case .fullTunnel:
            return nil
        case let .allowlist(packageNames):
            guard let packageName, packageNames.contains(packageName) else {
                return RoutePreviewOutcome(
                    action: .direct,
                    matchedRuleId: "__split_tunnel_allowlist__",
                    reason: "Application is outside the VPN allowlist."
                )
            }
            return nil
        case let .denylist(packageNames):
            guard let packageName, packageNames.contains(packageName) else { return nil }
            return RoutePreviewOutcome(
                action: .direct,
                matchedRuleId: "__split_tunnel_denylist__",
                reason: "Application is excluded by the VPN denylist."
            )
        }
    }

    private static func matches(_ rule: RouteRule, request: RoutePreviewRequest) throws -> Bool {
        let match = rule.match
        let domainMatches = matchesDomains(match, request: request)
        let cidrMatches = matchesCidrs(match, request: request)

        let hasRuntimeDatasetCriteria = !match.geoSites.isEmpty || !match.geoIps.isEmpty || !match.asns.isEmpty
        if hasRuntimeDatasetCriteria {
            let hasResolvableCriteria = !match.domainExact.isEmpty || !match.domainSuffix.isEmpty ||
                !match.domainKeyword.isEmpty || !match.ipCidrs.isEmpty
            let resolvedIndependently = hasResolvableCriteria && domainMatches && cidrMatches
            if !resolvedIndependently {
                return false
            }
        }

        return domainMatches &&
            matchesPackage(match, request: request) &&
            cidrMatches &&
            matchesPort(match, request: request) &&
            matchesProtocol(match, request: request)
    }

    private static func matchesDomains(_ match: RouteMatch, request: RoutePreviewRequest) -> Bool {
        guard let host = request.destinationHost else {
            return match.domainExact.isEmpty && match.domainSuffix.isEmpty && match.domainKeyword.isEmpty
        }

        let normalizedHost = normalizeDomainForMatching(host) ?? host.lowercased()
        let exactMatches = match.domainExact.isEmpty || match.domainExact.contains { candidate in
            (normalizeDomainForMatching(candidate) ?? candidate.lowercased()) == normalizedHost
        }
        let suffixMatches = match.domainSuffix.isEmpty || match.domainSuffix.contains { suffix in
            let normalizedSuffix = normalizeDomainForMatching(suffix) ?? suffix.lowercased()
            return normalizedHost == normalizedSuffix || normalizedHost.hasSuffix(".\(normalizedSuffix)")
        }
        let keywordMatches = match.domainKeyword.isEmpty || match.domainKeyword.contains { keyword in
            normalizedHost.contains(normalizeDomainForMatching(keyword) ?? keyword.lowercased())
        }
        return exactMatches && suffixMatches && keywordMatches
    }

    private static func matchesPackage(_ match: RouteMatch, request: RoutePreviewRequest) -> Bool {
        match.packageNames.isEmpty || (request.packageName.map { match.packageNames.contains($0) } ?? false)
    }

    private static func matchesPort(_ match: RouteMatch, request: RoutePreviewRequest) -> Bool {
        match.ports.isEmpty || (request.destinationPort.map { match.ports.contains($0) } ?? false)
    }

    private static func matchesProtocol(_ match: RouteMatch, request: RoutePreviewRequest) -> Bool {
        match.protocols.isEmpty || (request.`protocol`.map { match.protocols.contains($0) } ?? false)
    }

    private static func matchesCidrs(_ match: RouteMatch, request: RoutePreviewRequest) -> Bool {
        guard !match.ipCidrs.isEmpty else { return true }
        guard let ip = request.destinationIp, let address = ParsedIPAddress(ip) else { return false }
        return match.ipCidrs.contains { cidr in address.isInside(cidr: cidr) }
    }

    private static func isLoopback(host: String?, ip: String?) -> Bool {
        if let host {
            let normalized = host.lowercased()
            if normalized == "localhost" || normalized.hasSuffix(".localhost") {
                return true
            }
        }
        guard let ip, let address = ParsedIPAddress(ip) else { return false }
        return address.isLoopback
    }

    private static func runtimeDatasetHint(_ profile: ProfileIr, request: RoutePreviewRequest) -> String? {
        guard profile.routing.regionalBypass.isPresetEnabled(.russia) else { return nil }
        if request.destinationIp?.isEmpty == false {
            return "Regional bypass can still apply at runtime via geoip:ru classification for the destination IP."
        }
        guard let host = request.destinationHost, !host.isEmpty else { return nil }
        let normalizedHost = normalizeDomainForMatching(host)
        let suffixMatched = normalizedHost.map { candidate in
            ["ru", "su", "xn--p1ai"].contains { suffix in
                candidate == suffix || candidate.hasSuffix(".\(suffix)")
            }
        } ?? false
        if suffixMatched { return nil }
        return "Regional bypass can still apply at runtime if the resolved destination IP is classified as geoip:ru."
    }
}

private struct ParsedIPAddress: Equatable {
    let bytes: [UInt8]

    init?(_ rawValue: String) {
        if let address = IPv4Address(rawValue) {
            bytes = Array(address.rawValue)
        } else if let address = IPv6Address(rawValue) {
            bytes = Array(address.rawValue)
        } else {
            return nil
        }
    }

    var isLoopback: Bool {
        if bytes.count == 4 {
            return bytes[0] == 127
        }
        return bytes == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    }

    func isInside(cidr: String) -> Bool {
        let parts = cidr.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let network = Self(String(parts[0])),
              network.bytes.count == bytes.count,
              let prefixLength = Int(parts[1]),
              prefixLength >= 0,
              prefixLength <= bytes.count * 8 else {
            return false
        }

        var remainingBits = prefixLength
        for index in bytes.indices {
            guard remainingBits > 0 else { return true }
            let bitsToCompare = min(remainingBits, 8)
            let mask = UInt8(0xFF << (8 - bitsToCompare))
            if (network.bytes[index] & mask) != (bytes[index] & mask) {
                return false
            }
            remainingBits -= bitsToCompare
        }
        return true
    }
}
