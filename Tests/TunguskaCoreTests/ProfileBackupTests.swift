#if canImport(XCTest)
import XCTest
@testable import TunguskaCore

final class ProfileBackupTests: XCTestCase {
    func testRoundTripRestoresProfilesAndActiveProfile() throws {
        let profile = sampleProfile()
        let backup = try ProfileBackup.export(
            profiles: [profile],
            activeProfileID: profile.id,
            passphrase: "correct horse battery staple",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let restored = try ProfileBackup.import(
            data: backup,
            passphrase: "correct horse battery staple"
        )

        XCTAssertEqual(restored.profiles, [profile])
        XCTAssertEqual(restored.activeProfileID, profile.id)
        XCTAssertEqual(restored.createdAt.timeIntervalSince1970, 1_700_000_000, accuracy: 1)
    }

    func testBackupDoesNotContainPlaintextSecretsOrProfileNames() throws {
        let profile = sampleProfile()
        let backup = try ProfileBackup.export(
            profiles: [profile],
            activeProfileID: profile.id,
            passphrase: "correct horse battery staple"
        )
        let text = String(decoding: backup, as: UTF8.self)

        XCTAssertFalse(text.contains(profile.outbound.uuid))
        XCTAssertFalse(text.contains(profile.outbound.realityPublicKey))
        XCTAssertFalse(text.contains(profile.outbound.realityShortId))
        XCTAssertFalse(text.contains(profile.name))
    }

    func testWrongPassphraseFailsAuthentication() throws {
        let backup = try ProfileBackup.export(
            profiles: [sampleProfile()],
            activeProfileID: nil,
            passphrase: "correct horse battery staple"
        )

        XCTAssertThrowsError(
            try ProfileBackup.import(data: backup, passphrase: "wrong passphrase value")
        ) { error in
            XCTAssertEqual(error as? ProfileBackupError, .authenticationFailed)
        }
    }

    func testShortPassphraseIsRejected() {
        XCTAssertThrowsError(
            try ProfileBackup.export(
                profiles: [sampleProfile()],
                activeProfileID: nil,
                passphrase: "short"
            )
        ) { error in
            XCTAssertEqual(error as? ProfileBackupError, .passphraseTooShort)
        }
    }

    func testMissingActiveProfileIsRejected() {
        XCTAssertThrowsError(
            try ProfileBackup.export(
                profiles: [sampleProfile()],
                activeProfileID: "missing",
                passphrase: "correct horse battery staple"
            )
        ) { error in
            XCTAssertEqual(
                error as? ProfileBackupError,
                .invalidProfilePayload("The active profile is not present in the backup.")
            )
        }
    }

    func testUnsupportedVersionIsRejected() throws {
        let envelope = """
        {
          "format": "tunguska.profile-backup",
          "iterations": 210000,
          "kdf": "PBKDF2-HMAC-SHA256",
          "salt": "MDEyMzQ1Njc4OWFiY2RlZg==",
          "sealedBox": "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
          "version": 99
        }
        """

        XCTAssertThrowsError(
            try ProfileBackup.import(
                data: Data(envelope.utf8),
                passphrase: "correct horse battery staple"
            )
        ) { error in
            XCTAssertEqual(error as? ProfileBackupError, .unsupportedVersion(99))
        }
    }

    private func sampleProfile() -> ProfileIr {
        ProfileIr(
            id: "backup-profile",
            name: "Backup Profile",
            outbound: VlessRealityOutbound(
                address: "edge.example.com",
                port: 443,
                uuid: "11111111-1111-1111-1111-111111111111",
                serverName: "cdn.example.com",
                realityPublicKey: "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0",
                realityShortId: "abcd1234"
            )
        )
    }
}
#endif
