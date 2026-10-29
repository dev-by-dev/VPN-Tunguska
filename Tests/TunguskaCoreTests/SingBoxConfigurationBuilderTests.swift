#if canImport(XCTest)
import XCTest
@testable import TunguskaCore

final class SingBoxConfigurationBuilderTests: XCTestCase {
    func testBuildsRealityOutboundAndTunInbound() throws {
        let generated = try SingBoxConfigurationBuilder.build(profile: sampleProfile())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any])
        let outbounds = try XCTUnwrap(object["outbounds"] as? [[String: Any]])
        let proxy = try XCTUnwrap(outbounds.first { $0["tag"] as? String == "proxy" })

        XCTAssertEqual(proxy["type"] as? String, "vless")
        XCTAssertEqual(proxy["server"] as? String, "edge.example.com")
        XCTAssertEqual(proxy["server_port"] as? Int, 443)
        XCTAssertEqual(proxy["uuid"] as? String, "11111111-1111-1111-1111-111111111111")

        let tls = try XCTUnwrap(proxy["tls"] as? [String: Any])
        XCTAssertEqual(tls["enabled"] as? Bool, true)
        XCTAssertEqual(tls["server_name"] as? String, "cdn.example.com")
        let reality = try XCTUnwrap(tls["reality"] as? [String: Any])
        XCTAssertEqual(reality["public_key"] as? String, "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0")
        XCTAssertEqual(reality["short_id"] as? String, "abcd1234")

        let inbounds = try XCTUnwrap(object["inbounds"] as? [[String: Any]])
        let tun = try XCTUnwrap(inbounds.first)
        XCTAssertEqual(tun["type"] as? String, "tun")
        XCTAssertEqual(tun["address"] as? [String], ["172.19.0.1/30"])
    }

    func testBlockRuleBecomesRejectAction() throws {
        let profile = sampleProfile(routing: RoutingPolicy(
            rules: [
                RouteRule(id: "block", action: .block, match: RouteMatch(domainSuffix: ["tracker.example"])),
                RouteRule(id: "direct", action: .direct, match: RouteMatch(domainSuffix: ["ru"])),
            ],
            regionalBypass: RegionalBypassSettings()
        ))

        let generated = try SingBoxConfigurationBuilder.build(profile: profile)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any])
        let route = try XCTUnwrap(object["route"] as? [String: Any])
        let rules = try XCTUnwrap(route["rules"] as? [[String: Any]])

        XCTAssertEqual(rules[0]["action"] as? String, "reject")
        XCTAssertEqual(rules[1]["action"] as? String, "route")
        XCTAssertEqual(rules[1]["outbound"] as? String, "direct")
        XCTAssertEqual(route["final"] as? String, "proxy")
    }

    func testRegionalGeoIPIsWarnedAndOmitted() throws {
        let generated = try SingBoxConfigurationBuilder.build(profile: sampleProfile())
        XCTAssertTrue(generated.warnings.contains { $0.message.contains("GeoIP") })
        XCTAssertFalse(generated.json.contains("\"geoip\""))
        XCTAssertTrue(generated.json.contains("xn--p1ai"))
    }

    func testSystemDNSFallsBackToLocalResolver() throws {
        let generated = try SingBoxConfigurationBuilder.build(profile: sampleProfile(dns: .systemDns))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any])
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        XCTAssertEqual(dns["final"] as? String, "dns-local")
        XCTAssertEqual(dns["strategy"] as? String, "prefer_ipv4")
    }

    func testDoHEndpointBecomesEncryptedDNSTransport() throws {
        let generated = try SingBoxConfigurationBuilder.build(profile: sampleProfile(dns: .customEncrypted(
            kind: .doh,
            endpoints: ["https://1.1.1.1/dns-query"]
        )))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any])
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        XCTAssertEqual(dns["final"] as? String, "dns-remote-0")
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        let remote = try XCTUnwrap(servers.first { $0["tag"] as? String == "dns-remote-0" })
        XCTAssertEqual(remote["type"] as? String, "https")
        XCTAssertEqual(remote["server"] as? String, "1.1.1.1")
        XCTAssertEqual(remote["path"] as? String, "/dns-query")
        XCTAssertEqual(remote["detour"] as? String, "proxy")
    }

    func testUnsupportedDNSFallsBackWithWarning() throws {
        let generated = try SingBoxConfigurationBuilder.build(profile: sampleProfile(dns: .customEncrypted(
            kind: .doh,
            endpoints: ["not-a-url"]
        )))
        XCTAssertTrue(generated.warnings.contains { $0.field == "dns" })
        XCTAssertTrue(generated.json.contains("\"final\" : \"dns-local\""))
    }

    func testSystemProxyModeBuildsLoopbackMixedInbound() throws {
        let generated = try SingBoxConfigurationBuilder.build(profile: sampleProfile(), mode: .systemProxy)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any])
        let inbounds = try XCTUnwrap(object["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.count, 1)

        let mixed = try XCTUnwrap(inbounds.first)
        XCTAssertEqual(mixed["type"] as? String, "mixed")
        XCTAssertEqual(mixed["tag"] as? String, SingBoxConfigurationBuilder.mixedTag)
        XCTAssertEqual(mixed["listen"] as? String, HelperProtocol.proxyListenHost)
        XCTAssertEqual(mixed["listen_port"] as? Int, HelperProtocol.defaultProxyPort)
        XCTAssertFalse(inbounds.contains { $0["type"] as? String == "tun" }, "proxy mode must not create a TUN device")

        let outbounds = try XCTUnwrap(object["outbounds"] as? [[String: Any]])
        XCTAssertTrue(outbounds.contains { $0["tag"] as? String == "proxy" }, "VLESS outbound must remain the proxy")

        XCTAssertNoThrow(try HelperProtocol.validateStartConfiguration(generated.json, mode: .systemProxy))
    }

    func testTunModeIsTheDefaultBuild() throws {
        let defaultBuild = try SingBoxConfigurationBuilder.build(profile: sampleProfile())
        let tunBuild = try SingBoxConfigurationBuilder.build(profile: sampleProfile(), mode: .tun)

        XCTAssertEqual(defaultBuild.json, tunBuild.json)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(tunBuild.json.utf8)) as? [String: Any])
        let inbounds = try XCTUnwrap(object["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.first?["type"] as? String, "tun")
        XCTAssertFalse(inbounds.contains { $0["type"] as? String == "mixed" })
    }

    private func sampleProfile(
        dns: DnsMode = .systemDns,
        routing: RoutingPolicy = RoutingPolicy(regionalBypass: .default)
    ) -> ProfileIr {
        ProfileIr(
            id: "config",
            name: "Config",
            outbound: VlessRealityOutbound(
                address: "edge.example.com",
                port: 443,
                uuid: "11111111-1111-1111-1111-111111111111",
                serverName: "cdn.example.com",
                realityPublicKey: "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
                realityShortId: "abcd1234"
            ),
            routing: routing,
            dns: dns
        )
    }
}
#endif
