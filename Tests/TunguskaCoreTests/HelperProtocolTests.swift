#if canImport(XCTest)
import XCTest
@testable import TunguskaCore

final class HelperProtocolTests: XCTestCase {
    func testRequestRoundTripContainsOnlyExpectedFields() throws {
        let request = HelperRequest.start(
            profileID: "profile-1",
            config: "{\"inbounds\":[]}",
            expectedInterfaceAddress: "172.19.0.1"
        )

        let data = try HelperProtocol.encode(request)
        let decoded = try HelperProtocol.decodeRequest(data)

        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.action, .start)
        XCTAssertEqual(decoded.profileID, "profile-1")
        XCTAssertEqual(decoded.expectedInterfaceAddress, "172.19.0.1")
    }

    func testStatusRequestOmitsOptionalFields() throws {
        let data = try HelperProtocol.encode(.status())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["action"] as? String, "status")
        XCTAssertNil(object["profileID"])
        XCTAssertNil(object["config"])
        XCTAssertNil(object["expectedInterfaceAddress"])
    }

    func testValidateAcceptsTunguskaShapedConfiguration() throws {
        let config = """
        {
          "inbounds": [{"type": "tun", "tag": "tun-in"}],
          "outbounds": [
            {"type": "vless", "tag": "proxy"},
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"}
          ],
          "route": {"final": "proxy"}
        }
        """

        XCTAssertNoThrow(try HelperProtocol.validateStartConfiguration(config))
    }

    func testValidateRejectsMissingTunInbound() {
        let config = """
        {
          "inbounds": [{"type": "mixed", "tag": "mixed-in"}],
          "outbounds": [
            {"type": "vless", "tag": "proxy"},
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"}
          ],
          "route": {"final": "proxy"}
        }
        """

        XCTAssertThrowsError(try HelperProtocol.validateStartConfiguration(config)) { error in
            guard case HelperProtocolError.invalidConfiguration = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }
        }
    }

    func testValidateRejectsNonJsonConfiguration() {
        XCTAssertThrowsError(try HelperProtocol.validateStartConfiguration("not-json")) { error in
            guard case HelperProtocolError.invalidConfiguration = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }
        }
    }

    // MARK: - Command modes

    func testStartRequestRoundTripCarriesMode() throws {
        let request = HelperRequest.start(
            profileID: "profile-1",
            config: "{\"inbounds\":[]}",
            mode: .systemProxy,
            expectedInterfaceAddress: nil
        )

        let decoded = try HelperProtocol.decodeRequest(HelperProtocol.encode(request))

        XCTAssertEqual(decoded.mode, .systemProxy)
    }

    func testLegacyStartRequestWithoutModeDecodesAsNil() throws {
        let legacyJSON = """
        {"action":"start","profileID":"p","config":"{}","expectedInterfaceAddress":"172.19.0.1"}
        """

        let decoded = try HelperProtocol.decodeRequest(Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.action, .start)
        XCTAssertNil(decoded.mode, "legacy requests must decode without a mode and default to TUN")
    }

    func testValidateAcceptsLoopbackMixedForSystemProxyMode() throws {
        let config = """
        {
          "inbounds": [{"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 7890}],
          "outbounds": [
            {"type": "vless", "tag": "proxy"},
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"}
          ],
          "route": {"final": "proxy"}
        }
        """

        XCTAssertNoThrow(try HelperProtocol.validateStartConfiguration(config, mode: .systemProxy))
    }

    func testValidateSystemProxyModeRejectsTunInbound() {
        let config = """
        {
          "inbounds": [{"type": "tun", "tag": "tun-in"}],
          "outbounds": [
            {"type": "vless", "tag": "proxy"},
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"}
          ],
          "route": {"final": "proxy"}
        }
        """

        XCTAssertThrowsError(try HelperProtocol.validateStartConfiguration(config, mode: .systemProxy)) { error in
            guard case HelperProtocolError.invalidConfiguration = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }
        }
    }

    func testValidateSystemProxyModeRejectsNonLoopbackMixed() {
        let config = """
        {
          "inbounds": [{"type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 7890}],
          "outbounds": [
            {"type": "vless", "tag": "proxy"},
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"}
          ],
          "route": {"final": "proxy"}
        }
        """

        XCTAssertThrowsError(try HelperProtocol.validateStartConfiguration(config, mode: .systemProxy)) { error in
            guard case HelperProtocolError.invalidConfiguration = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }
        }
    }
}
#endif
