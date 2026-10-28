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
}
#endif
