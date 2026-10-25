import Foundation

public enum RouteAction: String, Codable, Equatable, Sendable {
    case proxy = "PROXY"
    case direct = "DIRECT"
    case block = "BLOCK"
}

public enum NetworkProtocol: String, Codable, Equatable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
}

public enum RegionalBypassPresetId: String, Codable, Equatable, Sendable {
    case russia
}

public struct RegionalBypassSettings: Codable, Equatable, Sendable {
    public var enabledPresets: [RegionalBypassPresetId]
    public var customDirectDomains: [String]

    public init(enabledPresets: [RegionalBypassPresetId] = [], customDirectDomains: [String] = []) {
        self.enabledPresets = enabledPresets
        self.customDirectDomains = customDirectDomains
    }

    public static let `default` = RegionalBypassSettings(enabledPresets: [.russia])

    public var isEmpty: Bool {
        enabledPresets.isEmpty && customDirectDomains.isEmpty
    }

    public func isPresetEnabled(_ preset: RegionalBypassPresetId) -> Bool {
        enabledPresets.contains(preset)
    }

    public func normalizedCustomDirectDomains() throws -> [String] {
        var seen: Set<String> = []
        return try customDirectDomains.compactMap { domain in
            let normalized = try normalizeDomainForRouting(domain)
            return seen.insert(normalized).inserted ? normalized : nil
        }
    }

    public func validationIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let duplicatePresets = Dictionary(grouping: enabledPresets, by: { $0 }).filter { $0.value.count > 1 }.keys
        for preset in duplicatePresets.sorted(by: { $0.rawValue < $1.rawValue }) {
            issues.append(.init(field: "routing.regionalBypass.enabledPresets", message: "Duplicate preset '\(preset.rawValue)'."))
        }

        var normalizedDomains: [String] = []
        for (index, domain) in customDirectDomains.enumerated() {
            if domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(field: "routing.regionalBypass.customDirectDomains[\(index)]", message: "Custom direct domains must not be blank."))
                continue
            }
            do {
                normalizedDomains.append(try normalizeDomainForRouting(domain))
            } catch {
                issues.append(.init(field: "routing.regionalBypass.customDirectDomains[\(index)]", message: error.localizedDescription))
            }
        }
        for duplicate in Dictionary(grouping: normalizedDomains, by: { $0 }).filter({ $0.value.count > 1 }).keys.sorted() {
            issues.append(.init(field: "routing.regionalBypass.customDirectDomains", message: "Duplicate direct domain '\(duplicate)'."))
        }
        return issues
    }

    private enum CodingKeys: String, CodingKey { case enabledPresets, customDirectDomains }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabledPresets = try values.decodeIfPresent([RegionalBypassPresetId].self, forKey: .enabledPresets) ?? []
        customDirectDomains = try values.decodeIfPresent([String].self, forKey: .customDirectDomains) ?? []
    }
}

public struct RouteMatch: Codable, Equatable, Sendable {
    public var domainExact: [String]
    public var domainSuffix: [String]
    public var domainKeyword: [String]
    public var ipCidrs: [String]
    public var geoSites: [String]
    public var geoIps: [String]
    public var asns: [Int64]
    public var packageNames: [String]
    public var ports: [Int]
    public var protocols: [NetworkProtocol]

    public init(
        domainExact: [String] = [],
        domainSuffix: [String] = [],
        domainKeyword: [String] = [],
        ipCidrs: [String] = [],
        geoSites: [String] = [],
        geoIps: [String] = [],
        asns: [Int64] = [],
        packageNames: [String] = [],
        ports: [Int] = [],
        protocols: [NetworkProtocol] = []
    ) {
        self.domainExact = domainExact
        self.domainSuffix = domainSuffix
        self.domainKeyword = domainKeyword
        self.ipCidrs = ipCidrs
        self.geoSites = geoSites
        self.geoIps = geoIps
        self.asns = asns
        self.packageNames = packageNames
        self.ports = ports
        self.protocols = protocols
    }

    public var hasCriteria: Bool {
        [domainExact.count, domainSuffix.count, domainKeyword.count, ipCidrs.count, geoSites.count,
         geoIps.count, asns.count, packageNames.count, ports.count, protocols.count].contains(where: { $0 > 0 })
    }

    private enum CodingKeys: String, CodingKey {
        case domainExact, domainSuffix, domainKeyword, ipCidrs, geoSites, geoIps
        case asns, packageNames, ports, protocols
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        domainExact = try values.decodeIfPresent([String].self, forKey: .domainExact) ?? []
        domainSuffix = try values.decodeIfPresent([String].self, forKey: .domainSuffix) ?? []
        domainKeyword = try values.decodeIfPresent([String].self, forKey: .domainKeyword) ?? []
        ipCidrs = try values.decodeIfPresent([String].self, forKey: .ipCidrs) ?? []
        geoSites = try values.decodeIfPresent([String].self, forKey: .geoSites) ?? []
        geoIps = try values.decodeIfPresent([String].self, forKey: .geoIps) ?? []
        asns = try values.decodeIfPresent([Int64].self, forKey: .asns) ?? []
        packageNames = try values.decodeIfPresent([String].self, forKey: .packageNames) ?? []
        ports = try values.decodeIfPresent([Int].self, forKey: .ports) ?? []
        protocols = try values.decodeIfPresent([NetworkProtocol].self, forKey: .protocols) ?? []
    }
}

public struct RouteRule: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var action: RouteAction
    public var match: RouteMatch

    public init(id: String, action: RouteAction, match: RouteMatch) {
        self.id = id
        self.action = action
        self.match = match
    }

    public func validationIssues(index: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "routing.rules[\(index)].id", message: "Route rule id must not be blank."))
        }
        if !match.hasCriteria {
            issues.append(.init(field: "routing.rules[\(index)].match", message: "Route rule must declare at least one criterion."))
        }
        for port in match.ports where !(1 ... 65_535).contains(port) {
            issues.append(.init(field: "routing.rules[\(index)].match.ports", message: "Invalid route port '\(port)'."))
        }
        return issues
    }
}

public struct RoutingPolicy: Codable, Equatable, Sendable {
    public var defaultAction: RouteAction
    public var rules: [RouteRule]
    public var regionalBypass: RegionalBypassSettings

    public init(
        defaultAction: RouteAction = .proxy,
        rules: [RouteRule] = [],
        regionalBypass: RegionalBypassSettings = RegionalBypassSettings()
    ) {
        self.defaultAction = defaultAction
        self.rules = rules
        self.regionalBypass = regionalBypass
    }

    public func validationIssues() -> [ValidationIssue] {
        var issues = regionalBypass.validationIssues()
        for duplicate in Dictionary(grouping: rules, by: { $0.id }).filter({ $0.value.count > 1 }).keys.sorted() {
            issues.append(.init(field: "routing.rules", message: "Duplicate route rule id '\(duplicate)'."))
        }
        for (index, rule) in rules.enumerated() {
            issues.append(contentsOf: rule.validationIssues(index: index))
        }
        return issues
    }

    private enum CodingKeys: String, CodingKey { case defaultAction, rules, regionalBypass }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        defaultAction = try values.decodeIfPresent(RouteAction.self, forKey: .defaultAction) ?? .proxy
        rules = try values.decodeIfPresent([RouteRule].self, forKey: .rules) ?? []
        regionalBypass = try values.decodeIfPresent(RegionalBypassSettings.self, forKey: .regionalBypass) ?? RegionalBypassSettings()
    }
}

public struct EffectiveRoutingPolicy: Equatable, Sendable {
    public let rules: [RouteRule]
    public let generatedRegionalRuleCount: Int
    public let enabledRegionalPresets: [RegionalBypassPresetId]
    public let normalizedCustomDirectDomains: [String]

    public init(rules: [RouteRule], generatedRegionalRuleCount: Int, enabledRegionalPresets: [RegionalBypassPresetId], normalizedCustomDirectDomains: [String]) {
        self.rules = rules
        self.generatedRegionalRuleCount = generatedRegionalRuleCount
        self.enabledRegionalPresets = enabledRegionalPresets
        self.normalizedCustomDirectDomains = normalizedCustomDirectDomains
    }
}

public enum EffectiveRoutingPolicyResolver {
    public static func resolve(_ profile: ProfileIr) throws -> EffectiveRoutingPolicy {
        try resolve(profile.routing)
    }

    public static func resolve(_ routing: RoutingPolicy) throws -> EffectiveRoutingPolicy {
        let settings = routing.regionalBypass
        var generatedRules: [RouteRule] = []
        for preset in settings.enabledPresets.uniqued() {
            switch preset {
            case .russia:
                generatedRules.append(RouteRule(
                    id: "__regional_bypass_russia__",
                    action: .direct,
                    match: RouteMatch(domainSuffix: ["ru", "su", "xn--p1ai"], geoIps: ["ru"])
                ))
            }
        }

        let customDomains = try settings.normalizedCustomDirectDomains()
        if !customDomains.isEmpty {
            generatedRules.append(RouteRule(
                id: "__regional_bypass_custom_direct__",
                action: .direct,
                match: RouteMatch(domainSuffix: customDomains)
            ))
        }

        return EffectiveRoutingPolicy(
            rules: routing.rules.filter { $0.action == .block } + generatedRules + routing.rules.filter { $0.action != .block },
            generatedRegionalRuleCount: generatedRules.count,
            enabledRegionalPresets: settings.enabledPresets.uniqued(),
            normalizedCustomDirectDomains: customDomains
        )
    }
}

public enum DomainNormalizationError: LocalizedError {
    case blank
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .blank: "Domain must not be blank."
        case let .invalid(domain): "Domain '\(domain)' is not a valid IDN hostname."
        }
    }
}

public func normalizeDomainForRouting(_ rawValue: String) throws -> String {
    var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("*.") { trimmed.removeFirst(2) }
    if trimmed.hasPrefix(".") { trimmed.removeFirst() }
    while trimmed.hasSuffix(".") { trimmed.removeLast() }
    guard !trimmed.isEmpty else { throw DomainNormalizationError.blank }
    guard !trimmed.contains("/"), !trimmed.contains(":"), !trimmed.contains("@"),
          trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
        throw DomainNormalizationError.invalid(rawValue)
    }

    var components = URLComponents()
    components.scheme = "https"
    components.host = trimmed
    guard let url = components.url,
          let asciiHost = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host,
          !asciiHost.isEmpty else {
        throw DomainNormalizationError.invalid(rawValue)
    }
    return asciiHost.lowercased()
}

public func normalizeDomainForMatching(_ rawValue: String) -> String? {
    try? normalizeDomainForRouting(rawValue)
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
