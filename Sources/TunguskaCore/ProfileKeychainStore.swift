import Foundation
import os
import Security

public enum ProfileKeychainStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidStoredProfile(account: String)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error \(status)"
            return "Keychain operation failed: \(message)"
        case let .invalidStoredProfile(account):
            return "The stored profile '\(account)' is corrupted and cannot be decoded."
        }
    }
}

/// Shared by the app and packet-tunnel extension.
///
/// A signed build must include the same Keychain access group in both targets. The group is
/// read from the generated Info.plist so unsigned local builds still use the default group.
public struct ProfileKeychainStore: Sendable {
    public static let shared = ProfileKeychainStore()

    public static let defaultService = "dev.tunguska.macos.profiles"
    public static let accessGroupInfoKey = "TunguskaKeychainAccessGroup"

    private let service: String
    private let accessGroup: String?
    private let activeProfileAccount = "__meta__.active-profile"

    private static let log = Logger(subsystem: "dev.tunguska.macos", category: "keychain")

    public init(
        service: String = ProfileKeychainStore.defaultService,
        accessGroup: String? = nil
    ) {
        self.service = service
        let resolvedGroup = accessGroup ?? Self.configuredAccessGroup()
        self.accessGroup = resolvedGroup
        let mode = resolvedGroup == nil ? "file-keychain" : "data-protection"
        Self.log.info("init service=\(service, privacy: .public) accessGroup=\(resolvedGroup ?? "nil", privacy: .public) mode=\(mode, privacy: .public)")
    }

    public func loadAll() throws -> [ProfileIr] {
        // The legacy file keychain rejects kSecMatchLimitAll combined with kSecReturnData
        // (errSecParam) on current macOS, so in that mode bulk-fetch attributes only and
        // pull each item's data with an individual query.
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true
        if accessGroup != nil {
            query[kSecReturnData as String] = true
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        Self.log.info("loadAll copyMatching status=\(status)")
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else {
            throw ProfileKeychainStoreError.unexpectedStatus(status)
        }
        guard let attributeItems = result as? [[String: Any]] else { return [] }
        Self.log.info("loadAll attribute items=\(attributeItems.count)")

        var items = attributeItems
        if accessGroup == nil {
            items = attributeItems.compactMap { item -> [String: Any]? in
                guard let account = item[kSecAttrAccount as String] as? String else { return nil }
                var dataQuery = itemQuery(account: account)
                dataQuery[kSecReturnData as String] = true
                var dataResult: CFTypeRef?
                let dataStatus = SecItemCopyMatching(dataQuery as CFDictionary, &dataResult)
                guard dataStatus == errSecSuccess, let data = dataResult as? Data else { return nil }
                var merged = item
                merged[kSecValueData as String] = data
                return merged
            }
        }

        let decoder = JSONDecoder()
        var profiles: [ProfileIr] = []
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String, account != activeProfileAccount,
                  let data = item[kSecValueData as String] as? Data else {
                continue
            }
            do {
                profiles.append(try decoder.decode(ProfileIr.self, from: data))
            } catch {
                throw ProfileKeychainStoreError.invalidStoredProfile(account: account)
            }
        }
        return profiles.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func loadProfile(id: String) throws -> ProfileIr? {
        var query = itemQuery(account: id)
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw ProfileKeychainStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw ProfileKeychainStoreError.invalidStoredProfile(account: id)
        }
        do {
            return try JSONDecoder().decode(ProfileIr.self, from: data)
        } catch {
            throw ProfileKeychainStoreError.invalidStoredProfile(account: id)
        }
    }

    public func save(_ profile: ProfileIr) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(profile)

        var query = itemQuery(account: profile.id)
        let existingStatus = SecItemCopyMatching(query as CFDictionary, nil)
        Self.log.info("save account=<hash> copyMatching status=\(existingStatus)")
        if existingStatus == errSecSuccess {
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            Self.log.info("save update status=\(status)")
            guard status == errSecSuccess else {
                throw ProfileKeychainStoreError.unexpectedStatus(status)
            }
            return
        }
        guard existingStatus == errSecItemNotFound else {
            throw ProfileKeychainStoreError.unexpectedStatus(existingStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        Self.log.info("save add dataBytes=\(data.count) status=\(status)")
        guard status == errSecSuccess else {
            throw ProfileKeychainStoreError.unexpectedStatus(status)
        }
    }

    public func deleteProfile(id: String) throws {
        let status = SecItemDelete(itemQuery(account: id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProfileKeychainStoreError.unexpectedStatus(status)
        }
    }

    public func loadActiveProfileID() throws -> String? {
        var query = itemQuery(account: activeProfileAccount)
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw ProfileKeychainStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            return nil
        }
        return value
    }

    public func setActiveProfileID(_ id: String?) throws {
        guard let id else {
            let status = SecItemDelete(itemQuery(account: activeProfileAccount) as CFDictionary)
            Self.log.info("setActive(nil) delete status=\(status)")
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw ProfileKeychainStoreError.unexpectedStatus(status)
            }
            return
        }

        guard try loadProfile(id: id) != nil else {
            throw ProfileKeychainStoreError.invalidStoredProfile(account: id)
        }

        var query = itemQuery(account: activeProfileAccount)
        let data = Data(id.utf8)
        let existingStatus = SecItemCopyMatching(query as CFDictionary, nil)
        Self.log.info("setActive copyMatching status=\(existingStatus)")
        if existingStatus == errSecSuccess {
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            Self.log.info("setActive update status=\(status)")
            guard status == errSecSuccess else {
                throw ProfileKeychainStoreError.unexpectedStatus(status)
            }
            return
        }
        guard existingStatus == errSecItemNotFound else {
            throw ProfileKeychainStoreError.unexpectedStatus(existingStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        Self.log.info("setActive add status=\(status)")
        guard status == errSecSuccess else {
            throw ProfileKeychainStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup {
            // A real Team-signed build has a keychain-access-groups entitlement. Use the
            // data-protection Keychain so the app and its tunnel extension share the group.
            query[kSecUseDataProtectionKeychain as String] = true
            query[kSecAttrAccessGroup as String] = accessGroup
        } else {
            // Ad-hoc/local builds have no Team ID and cannot carry restricted Keychain
            // entitlements. Fall back to the legacy file Keychain instead of failing every
            // operation with errSecMissingEntitlement.
            query[kSecUseDataProtectionKeychain as String] = false
        }
        return query
    }

    private func itemQuery(account: String) -> [String: Any] {
        var query = baseQuery()
        query[kSecAttrAccount as String] = account
        return query
    }

    private static func configuredAccessGroup() -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: accessGroupInfoKey) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }

        // An unsigned local build expands $(AppIdentifierPrefix) to an empty string, but has no
        // keychain-access-groups entitlement. Using that value would make every Keychain query
        // fail. Only opt into the shared group when the running process actually has it.
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(
                  task,
                  "keychain-access-groups" as CFString,
                  nil
              ) as? [String],
              groups.contains(trimmed) else {
            return nil
        }
        return trimmed
    }
}
