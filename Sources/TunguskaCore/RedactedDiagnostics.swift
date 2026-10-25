import Foundation

public enum RedactedDiagnosticsError: LocalizedError, Equatable {
    case serializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serializationFailed(let message):
            return "Could not serialize redacted diagnostics: \(message)"
        }
    }
}

/// Produces diagnostics that are safe to copy or attach to a bug report.
///
/// The report is redacted by construction: it never receives profile IDs, names,
/// endpoints, UUIDs, REALITY keys, short IDs, DNS endpoints, rule domains, or raw
/// share links. Only counts, enum-like categories, and validation field names are
/// emitted.
public enum RedactedDiagnostics {
    public static let schemaVersion = 1

    public static func build(
        profiles: [ProfileIr],
        activeProfileID: String?,
        appVersion: String,
        storage: String,
        tunnelStatus: String,
        generatedAt: Date = Date()
    ) throws -> String {
        let profileReports = profiles.map { profile in
            profileReport(profile, isActive: profile.id == activeProfileID)
        }

        let report: [String: Any] = [
            "schemaVersion": schemaVersion,
            "generatedAt": iso8601(generatedAt),
            "appVersion": appVersion,
            "storage": storage,
            "tunnelStatus": tunnelStatus,
            "profileCount": profiles.count,
            "activeProfileFound": activeProfileID.map { id in
                profiles.contains(where: { $0.id == id })
            } ?? false,
            "profiles": profileReports
        ]

        guard JSONSerialization.isValidJSONObject(report) else {
            throw RedactedDiagnosticsError.serializationFailed("report contains non-JSON values")
        }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: report,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            guard let text = String(data: data, encoding: .utf8) else {
                throw RedactedDiagnosticsError.serializationFailed("report is not UTF-8")
            }
            return text
        } catch let error as RedactedDiagnosticsError {
            throw error
        } catch {
            throw RedactedDiagnosticsError.serializationFailed(error.localizedDescription)
        }
    }

    private static func profileReport(_ profile: ProfileIr, isActive: Bool) -> [String: Any] {
        let issues = profile.validationIssues()
        let explicitRules = profile.routing.rules
        let rules = (try? EffectiveRoutingPolicyResolver.resolve(profile))?.rules ?? explicitRules
        let splitTunnel: String
        let splitTunnelEntryCount: Int
        switch profile.vpn.splitTunnel {
        case .fullTunnel:
            splitTunnel = "full_tunnel"
            splitTunnelEntryCount = 0
        case .allowlist(let packageNames):
            splitTunnel = "allowlist"
            splitTunnelEntryCount = packageNames.count
        case .denylist(let packageNames):
            splitTunnel = "denylist"
            splitTunnelEntryCount = packageNames.count
        }

        let dnsKind: String
        let encryptedDNSEndpointCount: Int
        switch profile.dns {
        case .vpnDns(let servers):
            dnsKind = "vpn_dns"
            encryptedDNSEndpointCount = servers.count
        case .systemDns:
            dnsKind = "system_dns"
            encryptedDNSEndpointCount = 0
        case .customEncrypted(_, let endpoints):
            dnsKind = "custom_encrypted"
            encryptedDNSEndpointCount = endpoints.count
        }

        let routingReport: [String: Any] = [
            "defaultAction": profile.routing.defaultAction.rawValue,
            "ruleCount": rules.count,
            "blockRuleCount": rules.filter { $0.action == .block }.count,
            "directRuleCount": rules.filter { $0.action == .direct }.count,
            "proxyRuleCount": rules.filter { $0.action == .proxy }.count,
            "regionalPresets": profile.routing.regionalBypass.enabledPresets.map(\.rawValue).sorted(),
            "customDirectDomainCount": profile.routing.regionalBypass.customDirectDomains.count
        ]
        let safetyReport: [String: Any] = [
            "safeMode": profile.safety.safeMode,
            "compatibilityLocalProxy": profile.safety.compatibilityLocalProxy,
            "debugEndpointsEnabled": profile.safety.debugEndpointsEnabled
        ]
        let validationReport: [String: Any] = [
            "issueCount": issues.count,
            "fields": Array(Set(issues.map(\.field))).sorted()
        ]
        return [
            "isActive": isActive,
            "outbound": "vless_reality",
            "flow": profile.outbound.flow ?? "none",
            "utlsFingerprint": profile.outbound.utlsFingerprint,
            "splitTunnel": splitTunnel,
            "splitTunnelEntryCount": splitTunnelEntryCount,
            "dnsKind": dnsKind,
            "encryptedDNSEndpointCount": encryptedDNSEndpointCount,
            "routing": routingReport,
            "safety": safetyReport,
            "validation": validationReport
        ]
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
