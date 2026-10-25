import Foundation
import TunguskaCore

struct CheckFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw CheckFailure(message: message)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw CheckFailure(message: "\(message). Expected \(expected), got \(actual).")
    }
}

func expectImportIssue(_ payload: String, field: String) throws {
    do {
        _ = try ProfileImportParser.parse(payload)
        throw CheckFailure(message: "Expected import failure for \(field).")
    } catch let error as ProfileImportError {
        try expect(error.issues.contains { $0.field == field }, "Expected issue field \(field), got \(error.issues)")
    }
}

let shareLink = "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
    "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234#Test%20Profile"
let imported = try ProfileImportParser.parse(shareLink)
try expectEqual(imported.profile.name, "Test Profile", "Share-link name")
try expectEqual(imported.profile.outbound.address, "edge.example.com", "Share-link host")
try expectEqual(imported.profile.outbound.serverName, "cdn.example.com", "REALITY SNI")
try expectEqual(imported.profile.outbound.utlsFingerprint, "chrome", "uTLS default")
try expectEqual(imported.profile.routing.regionalBypass.enabledPresets, [.russia], "Default regional bypass")

let alias = try ProfileImportParser.parse(
    "ess://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
        "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234&fp=firefox#Alias"
)
try expectEqual(alias.source.rawScheme, "ess", "ESS raw scheme")
try expectEqual(alias.profile.outbound.utlsFingerprint, "firefox", "ESS fingerprint")

try expectImportIssue(
    "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
        "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234&allowInsecure=1",
    field: "import.tls"
)
try expectImportIssue(
    "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
        "?security=reality&type=ws&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234",
    field: "import.type"
)

let canonicalJson = """
{
  "id": "import-json",
  "name": "Import Json",
  "outbound": {
    "address": "edge.example.com",
    "port": 443,
    "uuid": "11111111-1111-1111-1111-111111111111",
    "serverName": "cdn.example.com",
    "realityPublicKey": "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
    "realityShortId": "abcd1234"
  },
  "vpn": { "splitTunnel": { "kind": "full_tunnel" } },
  "routing": { "defaultAction": "PROXY", "rules": [] },
  "dns": { "kind": "system_dns" },
  "safety": {
    "safeMode": true,
    "compatibilityLocalProxy": false,
    "debugEndpointsEnabled": false
  }
}
"""
let jsonProfile = try ProfileImportParser.parse(canonicalJson)
try expectEqual(jsonProfile.source.format, .jsonProfile, "JSON source format")
try expectEqual(jsonProfile.profile.routing.regionalBypass.enabledPresets, [.russia], "JSON default regional bypass")

func previewProfile(
    vpn: VpnPolicy = VpnPolicy(),
    routing: RoutingPolicy = RoutingPolicy(regionalBypass: .default)
) -> ProfileIr {
    ProfileIr(
        id: "preview",
        name: "Preview",
        outbound: VlessRealityOutbound(
            address: "edge.example.com",
            port: 443,
            uuid: "11111111-1111-1111-1111-111111111111",
            serverName: "cdn.example.com",
            realityPublicKey: "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
            realityShortId: "abcd1234"
        ),
        vpn: vpn,
        routing: routing
    )
}

let blocked = try RoutePreviewEngine.evaluate(
    previewProfile(routing: RoutingPolicy(rules: [
        RouteRule(id: "block-tracker", action: .block, match: RouteMatch(domainSuffix: ["tracker.example"])),
        RouteRule(id: "direct-tracker", action: .direct, match: RouteMatch(domainSuffix: ["tracker.example"])),
    ], regionalBypass: .default)),
    request: RoutePreviewRequest(destinationHost: "api.tracker.example")
)
try expectEqual(blocked.action, .block, "Block precedence")
try expectEqual(blocked.matchedRuleId, "block-tracker", "Matched block rule")

let russian = try RoutePreviewEngine.evaluate(
    previewProfile(),
    request: RoutePreviewRequest(destinationHost: "www.yandex.ru")
)
try expectEqual(russian.action, .direct, "Russia direct")
try expectEqual(russian.matchedRuleId, "__regional_bypass_russia__", "Russia generated rule")

let defaultRoute = try RoutePreviewEngine.evaluate(
    previewProfile(),
    request: RoutePreviewRequest(destinationHost: "service.example")
)
try expectEqual(defaultRoute.action, .proxy, "Default proxy route")
try expect(defaultRoute.runtimeDatasetHint != nil, "GeoIP runtime hint")

let denylisted = try RoutePreviewEngine.evaluate(
    previewProfile(vpn: VpnPolicy(splitTunnel: .denylist(packageNames: ["com.example.bank"]))),
    request: RoutePreviewRequest(packageName: "com.example.bank", destinationHost: "bank.example")
)
try expectEqual(denylisted.action, .direct, "Denylisted application")
try expectEqual(denylisted.matchedRuleId, "__split_tunnel_denylist__", "Denylist generated rule")

let cidr = try RoutePreviewEngine.evaluate(
    previewProfile(routing: RoutingPolicy(rules: [
        RouteRule(id: "test-net", action: .direct, match: RouteMatch(ipCidrs: ["203.0.113.0/24"])),
    ], regionalBypass: .default)),
    request: RoutePreviewRequest(destinationIp: "203.0.113.10")
)
try expectEqual(cidr.action, .direct, "CIDR route")
try expectEqual(cidr.matchedRuleId, "test-net", "CIDR rule id")

if CommandLine.arguments.contains("--emit-config") {
    let generated = try SingBoxConfigurationBuilder.build(profile: previewProfile())
    print(generated.json)
    exit(EXIT_SUCCESS)
}

print("TunguskaCore validation passed.")
