#if canImport(XCTest)
import XCTest
@testable import TunguskaCore

final class RedactedDiagnosticsTests: XCTestCase {
    func testReportOmitsSecretsAndKeepsUsefulCounts() throws {
        let profile = sampleProfile()
        let report = try RedactedDiagnostics.build(
            profiles: [profile],
            activeProfileID: profile.id,
            appVersion: "0.1.0 (1)",
            storage: "macOS Keychain",
            tunnelStatus: "Disconnected",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        for secret in [
            profile.id,
            profile.name,
            profile.outbound.address,
            profile.outbound.uuid,
            profile.outbound.serverName,
            profile.outbound.realityPublicKey,
            profile.outbound.realityShortId,
            "edge.example.com",
            "cdn.example.com",
        ] {
            XCTAssertFalse(report.contains(secret), "Diagnostics leaked \(secret)")
        }

        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: Any]
        )
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)
        XCTAssertEqual(root["profileCount"] as? Int, 1)
        XCTAssertEqual(root["activeProfileFound"] as? Bool, true)
        XCTAssertEqual(root["tunnelStatus"] as? String, "Disconnected")

        let profiles = try XCTUnwrap(root["profiles"] as? [[String: Any]])
        let redacted = try XCTUnwrap(profiles.first)
        XCTAssertEqual(redacted["isActive"] as? Bool, true)
        XCTAssertEqual(redacted["outbound"] as? String, "vless_reality")
        XCTAssertEqual(redacted["dnsKind"] as? String, "system_dns")

        let routing = try XCTUnwrap(redacted["routing"] as? [String: Any])
        XCTAssertEqual(routing["defaultAction"] as? String, "PROXY")
        XCTAssertEqual(routing["ruleCount"] as? Int, 1)
        XCTAssertEqual(routing["directRuleCount"] as? Int, 1)
        XCTAssertEqual(routing["customDirectDomainCount"] as? Int, 0)

        let safety = try XCTUnwrap(redacted["safety"] as? [String: Any])
        XCTAssertEqual(safety["safeMode"] as? Bool, true)
        XCTAssertEqual(safety["compatibilityLocalProxy"] as? Bool, false)
        XCTAssertEqual(safety["debugEndpointsEnabled"] as? Bool, false)
    }

    func testMissingActiveProfileIsReportedWithoutInventingOne() throws {
        let profile = sampleProfile()
        let report = try RedactedDiagnostics.build(
            profiles: [profile],
            activeProfileID: "missing",
            appVersion: "0.1.0 (1)",
            storage: "macOS Keychain",
            tunnelStatus: "Disconnected"
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: Any]
        )
        XCTAssertEqual(root["activeProfileFound"] as? Bool, false)
        let profiles = try XCTUnwrap(root["profiles"] as? [[String: Any]])
        XCTAssertEqual(profiles.first?["isActive"] as? Bool, false)
    }

    private func sampleProfile() -> ProfileIr {
        ProfileIr(
            id: "diagnostics-profile",
            name: "Diagnostics Profile",
            outbound: VlessRealityOutbound(
                address: "edge.example.com",
                port: 443,
                uuid: "11111111-1111-1111-1111-111111111111",
                serverName: "cdn.example.com",
                realityPublicKey: "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
                realityShortId: "abcd1234"
            ),
            routing: RoutingPolicy(regionalBypass: .default),
            dns: .systemDns
        )
    }
}
#endif
