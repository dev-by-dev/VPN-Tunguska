#if canImport(XCTest)
import XCTest
@testable import TunguskaCore

final class RoutePreviewEngineTests: XCTestCase {
    func testBlockRuleWinsOverRegionalBypass() throws {
        let profile = sampleProfile(routing: RoutingPolicy(
            rules: [
                RouteRule(
                    id: "block-tracker",
                    action: .block,
                    match: RouteMatch(domainSuffix: ["tracker.example"])
                ),
                RouteRule(
                    id: "direct-tracker",
                    action: .direct,
                    match: RouteMatch(domainSuffix: ["tracker.example"])
                ),
            ],
            regionalBypass: .default
        ))

        let outcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(destinationHost: "api.tracker.example")
        )

        XCTAssertEqual(outcome.action, .block)
        XCTAssertEqual(outcome.matchedRuleId, "block-tracker")
    }

    func testRussiaPresetMatchesRussianDomain() throws {
        let outcome = try RoutePreviewEngine.evaluate(
            sampleProfile(),
            request: RoutePreviewRequest(destinationHost: "www.yandex.ru")
        )

        XCTAssertEqual(outcome.action, .direct)
        XCTAssertEqual(outcome.matchedRuleId, "__regional_bypass_russia__")
        XCTAssertNil(outcome.runtimeDatasetHint)
    }

    func testCustomDirectDomainUsesSuffixMatch() throws {
        let profile = sampleProfile(routing: RoutingPolicy(
            regionalBypass: RegionalBypassSettings(
                enabledPresets: [],
                customDirectDomains: ["corp.example"]
            )
        ))

        let outcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(destinationHost: "api.corp.example")
        )

        XCTAssertEqual(outcome.action, .direct)
        XCTAssertEqual(outcome.matchedRuleId, "__regional_bypass_custom_direct__")
    }

    func testDefaultRouteAppliesWhenNoRuleMatches() throws {
        let outcome = try RoutePreviewEngine.evaluate(
            sampleProfile(),
            request: RoutePreviewRequest(destinationHost: "service.example")
        )

        XCTAssertEqual(outcome.action, .proxy)
        XCTAssertNil(outcome.matchedRuleId)
        XCTAssertNotNil(outcome.runtimeDatasetHint)
    }

    func testLoopbackAlwaysStaysLocal() throws {
        let outcome = try RoutePreviewEngine.evaluate(
            sampleProfile(routing: RoutingPolicy(defaultAction: .block, regionalBypass: .default)),
            request: RoutePreviewRequest(destinationHost: "localhost", destinationPort: 8080)
        )

        XCTAssertEqual(outcome.action, .direct)
        XCTAssertEqual(outcome.matchedRuleId, "__loopback__")
    }

    func testDenylistApplicationStaysDirect() throws {
        let profile = sampleProfile(vpn: VpnPolicy(
            splitTunnel: .denylist(packageNames: ["com.example.bank"])
        ))

        let outcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(
                packageName: "com.example.bank",
                destinationHost: "bank.example"
            )
        )

        XCTAssertEqual(outcome.action, .direct)
        XCTAssertEqual(outcome.matchedRuleId, "__split_tunnel_denylist__")
    }

    func testAllowlistApplicationOutsideListStaysDirect() throws {
        let profile = sampleProfile(vpn: VpnPolicy(
            splitTunnel: .allowlist(packageNames: ["com.example.browser"])
        ))

        let outcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(
                packageName: "com.example.mail",
                destinationHost: "mail.example"
            )
        )

        XCTAssertEqual(outcome.action, .direct)
        XCTAssertEqual(outcome.matchedRuleId, "__split_tunnel_allowlist__")
    }

    func testExplicitCidrRuleMatchesDestinationIp() throws {
        let profile = sampleProfile(routing: RoutingPolicy(
            rules: [
                RouteRule(
                    id: "private-direct",
                    action: .direct,
                    match: RouteMatch(ipCidrs: ["203.0.113.0/24"])
                ),
            ],
            regionalBypass: .default
        ))

        let outcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(destinationIp: "203.0.113.10")
        )

        XCTAssertEqual(outcome.action, .direct)
        XCTAssertEqual(outcome.matchedRuleId, "private-direct")
    }

    func testPortAndProtocolCriteriaAreCombined() throws {
        let profile = sampleProfile(routing: RoutingPolicy(
            rules: [
                RouteRule(
                    id: "https-proxy",
                    action: .proxy,
                    match: RouteMatch(ports: [443], protocols: [.tcp])
                ),
            ],
            regionalBypass: .default
        ))

        let tcpOutcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(destinationHost: "service.example", destinationPort: 443, protocol: .tcp)
        )
        let udpOutcome = try RoutePreviewEngine.evaluate(
            profile,
            request: RoutePreviewRequest(destinationHost: "service.example", destinationPort: 443, protocol: .udp)
        )

        XCTAssertEqual(tcpOutcome.matchedRuleId, "https-proxy")
        XCTAssertEqual(udpOutcome.action, .proxy)
        XCTAssertNil(udpOutcome.matchedRuleId)
    }

    func testRegionalRuleDoesNotClaimGeoIpMatchForForeignIp() throws {
        let outcome = try RoutePreviewEngine.evaluate(
            sampleProfile(),
            request: RoutePreviewRequest(destinationIp: "203.0.113.10")
        )

        XCTAssertEqual(outcome.action, .proxy)
        XCTAssertNil(outcome.matchedRuleId)
        XCTAssertNotNil(outcome.runtimeDatasetHint)
    }

    private func sampleProfile(
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
}
#endif
