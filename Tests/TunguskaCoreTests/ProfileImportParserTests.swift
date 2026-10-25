#if canImport(XCTest)
import XCTest
@testable import TunguskaCore

final class ProfileImportParserTests: XCTestCase {
    func testParsesVlessRealityShareLink() throws {
        let imported = try ProfileImportParser.parse(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234#Test%20Profile"
        )

        XCTAssertEqual(imported.profile.name, "Test Profile")
        XCTAssertEqual(imported.profile.outbound.address, "edge.example.com")
        XCTAssertEqual(imported.profile.outbound.port, 443)
        XCTAssertEqual(imported.profile.outbound.uuid, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(imported.profile.outbound.serverName, "cdn.example.com")
        XCTAssertEqual(imported.profile.outbound.realityPublicKey, "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0")
        XCTAssertEqual(imported.profile.outbound.realityShortId, "abcd1234")
        XCTAssertEqual(imported.profile.outbound.utlsFingerprint, "chrome")
        XCTAssertEqual(imported.profile.routing.regionalBypass.enabledPresets, [.russia])
        XCTAssertEqual(imported.source.format, .vlessRealityURI)
        XCTAssertTrue(imported.warnings.isEmpty)
    }

    func testParsesEssAliasAndPreservesFingerprintAndFlow() throws {
        let imported = try ProfileImportParser.parse(
            "ess://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&type=tcp&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234" +
                "&fp=firefox&flow=xtls-rprx-vision#Alias"
        )

        XCTAssertEqual(imported.source.rawScheme, "ess")
        XCTAssertEqual(imported.source.normalizedScheme, "vless")
        XCTAssertEqual(imported.profile.outbound.utlsFingerprint, "firefox")
        XCTAssertEqual(imported.profile.outbound.flow, "xtls-rprx-vision")
    }

    func testWarnsAboutUnsupportedQueryParameters() throws {
        let imported = try ProfileImportParser.parse(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234&remark=ignored#Profile"
        )

        XCTAssertTrue(imported.warnings.contains { $0.contains("remark") })
    }

    func testUsesHostWhenFragmentIsMissing() throws {
        let imported = try ProfileImportParser.parse(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234"
        )

        XCTAssertEqual(imported.profile.name, "edge.example.com")
        XCTAssertTrue(imported.warnings.contains { $0.contains("fragment missing") })
    }

    func testRejectsInsecureTlsFlag() {
        assertImportFails(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234&allowInsecure=1",
            field: "import.tls"
        )
    }

    func testRejectsNonRealitySecurity() {
        assertImportFails(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=tls&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234",
            field: "import.security"
        )
    }

    func testRejectsUnsupportedTransport() {
        assertImportFails(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&type=ws&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234",
            field: "import.type"
        )
    }

    func testRejectsMissingRealityFields() {
        assertImportFails(
            "vless://11111111-1111-1111-1111-111111111111@edge.example.com:443" +
                "?security=reality&sni=cdn.example.com",
            field: "import.realityPublicKey"
        )
    }

    func testParsesCanonicalJsonProfileAndAppliesDefaultRegionalBypass() throws {
        let json = """
        {
          "id": "import-json",
          "name": "Import Json",
          "outbound": {
            "address": "edge.example.com",
            "port": 443,
            "uuid": "11111111-1111-1111-1111-111111111111",
            "serverName": "cdn.example.com",
            "realityPublicKey": "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
            "realityShortId": "abcd1234",
            "utlsFingerprint": "chrome"
          },
          "vpn": {
            "splitTunnel": {
              "kind": "full_tunnel"
            }
          },
          "routing": {
            "defaultAction": "PROXY",
            "rules": []
          },
          "dns": {
            "kind": "system_dns"
          },
          "safety": {
            "safeMode": true,
            "compatibilityLocalProxy": false,
            "debugEndpointsEnabled": false
          }
        }
        """

        let imported = try ProfileImportParser.parse(json)

        XCTAssertEqual(imported.source.format, .jsonProfile)
        XCTAssertEqual(imported.profile.routing.regionalBypass.enabledPresets, [.russia])
    }

    func testPreservesExplicitEmptyRegionalBypassFromJson() throws {
        let profile = sampleProfile(routing: RoutingPolicy(regionalBypass: RegionalBypassSettings()))
        let data = try JSONEncoder().encode(profile)
        let json = String(decoding: data, as: UTF8.self)

        let imported = try ProfileImportParser.parse(json)

        XCTAssertTrue(imported.profile.routing.regionalBypass.enabledPresets.isEmpty)
    }

    func testRejectsJsonProfileWithDisabledSafeMode() throws {
        let unsafe = sampleProfile(safety: SafetySettings(safeMode: false))
        let data = try JSONEncoder().encode(unsafe)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertThrowsError(try ProfileImportParser.parse(json)) { error in
            guard let importError = error as? ProfileImportError else {
                return XCTFail("Expected ProfileImportError, got \(error)")
            }
            XCTAssertTrue(importError.issues.contains { $0.field == "import.safety.safeMode" })
        }
    }

    private func assertImportFails(_ input: String, field: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try ProfileImportParser.parse(input), file: file, line: line) { error in
            guard let importError = error as? ProfileImportError else {
                XCTFail("Expected ProfileImportError, got \(error)", file: file, line: line)
                return
            }
            XCTAssertTrue(importError.issues.contains { $0.field == field }, "Missing issue for \(field): \(importError.issues)", file: file, line: line)
        }
    }

    private func sampleProfile(
        routing: RoutingPolicy = RoutingPolicy(),
        safety: SafetySettings = SafetySettings()
    ) -> ProfileIr {
        ProfileIr(
            id: "import-json",
            name: "Import Json",
            outbound: VlessRealityOutbound(
                address: "edge.example.com",
                port: 443,
                uuid: "11111111-1111-1111-1111-111111111111",
                serverName: "cdn.example.com",
                realityPublicKey: "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
                realityShortId: "abcd1234"
            ),
            routing: routing,
            safety: safety
        )
    }
}
#endif
