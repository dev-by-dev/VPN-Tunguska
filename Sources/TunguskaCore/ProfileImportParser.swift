import CryptoKit
import Foundation

public enum ImportedProfileFormat: String, Codable, Equatable, Sendable {
    case vlessRealityURI = "VLESS_REALITY_URI"
    case jsonProfile = "JSON_PROFILE"
}

public struct ImportedProfileSource: Equatable, Sendable {
    public let rawScheme: String
    public let normalizedScheme: String
    public let format: ImportedProfileFormat
    public let summary: String

    public init(rawScheme: String, normalizedScheme: String, format: ImportedProfileFormat, summary: String) {
        self.rawScheme = rawScheme
        self.normalizedScheme = normalizedScheme
        self.format = format
        self.summary = summary
    }
}

public struct ImportedProfile: Equatable, Sendable {
    public let profile: ProfileIr
    public let source: ImportedProfileSource
    public let warnings: [String]

    public init(profile: ProfileIr, source: ImportedProfileSource, warnings: [String] = []) {
        self.profile = profile
        self.source = source
        self.warnings = warnings
    }
}

public struct ProfileImportError: LocalizedError {
    public let issues: [ValidationIssue]

    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }

    public var errorDescription: String? {
        guard !issues.isEmpty else { return "Profile import failed." }
        let details = issues.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
        return "Profile import failed: \(details)"
    }
}

public enum ProfileImportParser {
    private static let maxImportPayloadCharacters = 8_192
    private static let supportedShareShapeLabel = "VLESS + REALITY over TCP"
    private static let supportedQueryKeys: Set<String> = [
        "allowInsecure",
        "encryption",
        "fingerprint",
        "flow",
        "fp",
        "insecure",
        "pbk",
        "publicKey",
        "security",
        "serverName",
        "shortId",
        "sid",
        "spiderX",
        "spx",
        "sni",
        "type",
    ]

    public static func parse(_ rawInput: String) throws -> ImportedProfile {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            throw ProfileImportError(issues: [issue("import.payload", "Import payload must not be blank.")])
        }
        guard input.count <= maxImportPayloadCharacters else {
            throw ProfileImportError(issues: [issue("import.payload", "Import payload exceeds the \(maxImportPayloadCharacters) character limit.")])
        }

        if input.hasPrefix("{") {
            return try parseJsonProfile(input)
        }
        return try parseShareUri(input)
    }

    private static func parseShareUri(_ input: String) throws -> ImportedProfile {
        let normalizedInput = input.replacingOccurrences(of: " ", with: "%20")
        guard let components = URLComponents(string: normalizedInput) else {
            throw ProfileImportError(issues: [issue("import.uri", "Import payload is not a valid URI.")])
        }

        var issues: [ValidationIssue] = []
        let scheme = components.scheme?.lowercased() ?? ""
        if scheme != "vless" && scheme != "ess" {
            issues.append(issue("import.scheme", "Only vless:// and ess:// share links for the current \(supportedShareShapeLabel) shape are supported."))
        }

        let userInfo = decodeComponent(components.percentEncodedUser)
        if userInfo.isEmpty {
            issues.append(issue("import.uuid", "VLESS URI must contain a UUID userinfo component."))
        }

        let host = components.host ?? ""
        if host.isEmpty {
            issues.append(issue("import.address", "VLESS URI must contain a server host."))
        }

        let port = components.port ?? -1
        if !(1 ... 65_535).contains(port) {
            issues.append(issue("import.port", "VLESS URI must contain a port between 1 and 65535."))
        }

        let query = parseQuery(components.percentEncodedQuery)
        if query["security"]?.lowercased() != "reality" {
            issues.append(issue("import.security", "Only the REALITY security layer is accepted for the current \(supportedShareShapeLabel) import shape."))
        }

        if let transportType = query["type"]?.lowercased(), transportType != "tcp" {
            issues.append(issue("import.type", "Only the TCP transport is accepted for the current \(supportedShareShapeLabel) import shape."))
        }

        if let encryption = query["encryption"]?.lowercased(), encryption != "none" {
            issues.append(issue("import.encryption", "VLESS encryption must be omitted or set to 'none'."))
        }

        let flow = query["flow"]
        if let flow, flow != requiredVLESSFlow {
            issues.append(issue("import.flow", "Only \(requiredVLESSFlow) is accepted."))
        }

        if isTruthy(query["allowInsecure"]) || isTruthy(query["insecure"]) {
            issues.append(issue("import.tls", "Insecure TLS flags are rejected."))
        }

        let serverName = query["sni"] ?? query["serverName"]
        if serverName?.isEmpty != false {
            issues.append(issue("import.sni", "REALITY imports must specify an SNI/serverName."))
        }

        let publicKey = query["pbk"] ?? query["publicKey"]
        if publicKey?.isEmpty != false {
            issues.append(issue("import.realityPublicKey", "REALITY imports must specify a public key."))
        }

        let shortId = query["sid"] ?? query["shortId"]
        if shortId?.isEmpty != false {
            issues.append(issue("import.realityShortId", "REALITY imports must specify a short id."))
        }

        let spiderX = query["spx"] ?? query["spiderX"]
        if !issues.isEmpty {
            throw ProfileImportError(issues: issues)
        }

        var warnings: [String] = []
        if normalizedInput != input {
            warnings.append("Normalized raw spaces in the imported share link.")
        }
        let ignoredKeys = Set(query.keys).subtracting(supportedQueryKeys).sorted()
        if !ignoredKeys.isEmpty {
            warnings.append("Ignored unsupported query parameters: \(ignoredKeys.joined(separator: ", ")).")
        }

        var name = decodeComponent(components.percentEncodedFragment)
        if name.isEmpty {
            warnings.append("URI fragment missing; using server host as the profile name.")
            name = host
        }

        let profile = ProfileIr(
            id: "import-\(sha256Hex(input).prefix(12))",
            name: name,
            outbound: VlessRealityOutbound(
                address: host,
                port: port,
                uuid: userInfo,
                serverName: serverInfo(from: serverName),
                realityPublicKey: publicKey ?? "",
                realityShortId: shortId ?? "",
                realitySpiderX: spiderX,
                flow: flow,
                utlsFingerprint: query["fp"] ?? query["fingerprint"] ?? "chrome"
            ),
            routing: RoutingPolicy(regionalBypass: .default)
        )

        let validationIssues = profile.validationIssues()
        if !validationIssues.isEmpty {
            throw ProfileImportError(issues: validationIssues)
        }

        return ImportedProfile(
            profile: profile,
            source: ImportedProfileSource(
                rawScheme: scheme,
                normalizedScheme: "vless",
                format: .vlessRealityURI,
                summary: scheme == "ess"
                    ? "Validated an ess:// alias as a \(supportedShareShapeLabel) share link."
                    : "Validated a \(supportedShareShapeLabel) share link."
            ),
            warnings: warnings
        )
    }

    private static func parseJsonProfile(_ input: String) throws -> ImportedProfile {
        guard let data = input.data(using: .utf8) else {
            throw ProfileImportError(issues: [issue("import.json", "Import payload is not valid UTF-8.")])
        }

        let rawObject = try? JSONSerialization.jsonObject(with: data)
        guard rawObject is [String: Any] else {
            throw ProfileImportError(issues: [issue("import.json", "Import payload is not valid ProfileIr JSON.")])
        }

        var profile: ProfileIr
        do {
            profile = try JSONDecoder().decode(ProfileIr.self, from: data)
        } catch {
            throw ProfileImportError(issues: [issue("import.json", "Import payload is not valid ProfileIr JSON.")])
        }

        if !routingContainsRegionalBypass(rawObject) {
            profile.routing.regionalBypass = .default
        }

        var issues = profile.validationIssues()
        if !profile.safety.safeMode {
            issues.append(issue("import.safety.safeMode", "Imported profiles must keep safe mode enabled."))
        }
        if profile.safety.compatibilityLocalProxy {
            issues.append(issue("import.safety.compatibilityLocalProxy", "Imported profiles cannot enable compatibility localhost proxy mode."))
        }
        if profile.safety.debugEndpointsEnabled {
            issues.append(issue("import.safety.debugEndpointsEnabled", "Imported profiles cannot enable debug endpoints."))
        }
        if !issues.isEmpty {
            throw ProfileImportError(issues: issues)
        }

        return ImportedProfile(
            profile: profile,
            source: ImportedProfileSource(
                rawScheme: "json",
                normalizedScheme: "json",
                format: .jsonProfile,
                summary: "Validated a canonical JSON profile."
            )
        )
    }

    private static func parseQuery(_ rawQuery: String?) -> [String: String] {
        guard let rawQuery, !rawQuery.isEmpty else { return [:] }
        var result: [String: String] = [:]
        for pair in rawQuery.split(separator: "&", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = decodeComponent(parts.first.map(String.init) ?? "")
            let value = parts.count > 1 ? decodeComponent(String(parts[1])) : ""
            result[key] = value
        }
        return result
    }

    private static func decodeComponent(_ value: String?) -> String {
        guard let value else { return "" }
        let prepared = value.replacingOccurrences(of: "+", with: "%2B")
        return prepared.removingPercentEncoding ?? prepared
    }

    private static func serverInfo(from value: String?) -> String {
        value ?? ""
    }

    private static func isTruthy(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private static func issue(_ field: String, _ message: String) -> ValidationIssue {
        ValidationIssue(field: field, message: message)
    }

    private static func routingContainsRegionalBypass(_ object: Any?) -> Bool {
        guard let dictionary = object as? [String: Any],
              let routing = dictionary["routing"] as? [String: Any] else {
            return false
        }
        return routing["regionalBypass"] != nil
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
