#if DEBUG
import Darwin
import Foundation
import os
import TunguskaCore

enum KeychainSelfTest {
    private static let sampleProfile = """
    vless://00000000-0000-4000-8000-000000000001@example.com:443?security=reality&sni=cdn.example.com&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=abcd1234&fp=chrome&flow=xtls-rprx-vision#Keychain%20Self%20Test
    """

    static func runIfRequested() {
        guard CommandLine.arguments.contains("--keychain-self-test") else { return }

        let store = ProfileKeychainStore.shared
        do {
            let imported = try ProfileImportParser.parse(sampleProfile)
            try store.save(imported.profile)
            guard let loaded = try store.loadProfile(id: imported.profile.id) else {
                throw SelfTestError.profileWasNotLoaded
            }
            try store.setActiveProfileID(loaded.id)
            let activeID = try store.loadActiveProfileID()
            try store.deleteProfile(id: loaded.id)
            if activeID == loaded.id {
                try store.setActiveProfileID(nil)
            }
            os_log(
                "KEYCHAIN_SELF_TEST_OK id=%{public}@",
                log: SelfTestLog.handle,
                type: .default,
                loaded.id
            )
            exit(EXIT_SUCCESS)
        } catch {
            os_log(
                "KEYCHAIN_SELF_TEST_FAILED %{public}@",
                log: SelfTestLog.handle,
                type: .error,
                error.localizedDescription
            )
            exit(EXIT_FAILURE)
        }
    }

    private enum SelfTestLog {
        static let handle = OSLog(subsystem: "dev.tunguska.macos", category: "self-test")
    }

    private enum SelfTestError: LocalizedError {
        case profileWasNotLoaded

        var errorDescription: String? {
            "The saved profile could not be loaded back from Keychain."
        }
    }
}
#endif
