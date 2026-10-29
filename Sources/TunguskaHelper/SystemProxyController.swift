import Foundation
import SystemConfiguration
import TunguskaCore
import TunguskaSCShim

enum SystemProxyError: LocalizedError, Equatable {
    case preferencesUnavailable
    case servicesUnavailable
    case commitFailed(String)
    case snapshotUnreadable

    var errorDescription: String? {
        switch self {
        case .preferencesUnavailable:
            return "Could not open the macOS network preferences."
        case .servicesUnavailable:
            return "No configurable network services were found."
        case let .commitFailed(message):
            return "macOS refused the proxy configuration change: \(message)"
        case .snapshotUnreadable:
            return "The saved system-proxy snapshot could not be read."
        }
    }
}

/// Applies and restores the macOS system-wide proxy configuration, mirroring the
/// Clash Verge sysproxy flow: rewrite every network service's Proxies dictionary
/// through SCPreferences (running as root needs no authorization prompt), snapshot
/// the previous values first, and restore them verbatim when the session stops.
///
/// The snapshot on disk doubles as crash recovery: if the helper dies mid-session,
/// the next daemon launch restores the saved settings instead of leaving the
/// system pointed at a dead proxy.
enum SystemProxyController {
    private static var snapshotURL: URL {
        HelperInstallation.runtimeDirectory.appendingPathComponent("sysproxy-snapshot.plist")
    }

    /// Domains that must never be sent through the proxy.
    private static let bypassDomains = [
        "localhost",
        "127.0.0.1",
        "::1",
        "192.168.0.0/16",
        "10.0.0.0/8",
        "172.16.0.0/12",
        "169.254.0.0/16",
        "*.local",
    ]

    /// True when a previous apply() has not been restored yet.
    static var isConfigured: Bool {
        FileManager.default.fileExists(atPath: snapshotURL.path)
    }

    /// Per-service dictionary key for proxy settings ("Proxies" in the
    /// SCPreferences schema; the SDK no longer exports kSCPropNetProxies).
    private static let serviceProxiesKey = "Proxies"

    /// Points HTTP, HTTPS, and SOCKS proxies of every network service at the local
    /// mixed inbound. Existing per-service proxy dictionaries are snapshotted first.
    /// `resnapshot: false` re-applies the same settings without touching the saved
    /// snapshot; the proxy guard uses it after another app resets the system proxy.
    static func apply(port: Int, resnapshot: Bool = true) throws {
        let preferences = SCPreferencesCreate(nil, "dev.tunguska.macos.helper" as CFString, nil)
        guard let preferences else {
            throw SystemProxyError.preferencesUnavailable
        }
        var services = try readServices(from: preferences)

        var snapshot: [String: [String: Any]] = [:]
        for (serviceID, service) in services where service["Interface"] is [String: Any] {
            if resnapshot {
                let existing = service[serviceProxiesKey] as? [String: Any] ?? [:]
                snapshot[serviceID] = existing
            }

            var updated = service
            updated[serviceProxiesKey] = proxySettings(port: port, preserving: service[serviceProxiesKey] as? [String: Any] ?? [:])
            services[serviceID] = updated
        }
        guard !resnapshot || !snapshot.isEmpty else {
            throw SystemProxyError.servicesUnavailable
        }

        if resnapshot {
            try writePlist(snapshot, to: snapshotURL)
        }
        do {
            try commit(services, using: preferences)
        } catch {
            // Never leave a snapshot behind for settings that were not applied.
            if resnapshot {
                try? FileManager.default.removeItem(at: snapshotURL)
            }
            throw error
        }
    }

    /// True when the live system-wide proxy state still points at the local mixed
    /// inbound. The proxy guard polls this and re-applies on drift.
    static func systemProxiesMatch(port: Int) -> Bool {
        guard let dictionary = tunguska_SCDynamicStoreCopyGlobalProxies() else {
            return false
        }
        let proxies = dictionary as NSDictionary as? [String: Any] ?? [:]

        func isEnabled(_ key: String) -> Bool { (proxies[key] as? Int) == 1 }
        func host(_ key: String) -> String? { proxies[key] as? String }
        func proxyPort(_ key: String) -> Int? { proxies[key] as? Int }

        let listenHost = HelperProtocol.proxyListenHost
        return isEnabled(kSCPropNetProxiesHTTPEnable as String)
            && host(kSCPropNetProxiesHTTPProxy as String) == listenHost
            && proxyPort(kSCPropNetProxiesHTTPPort as String) == port
            && isEnabled(kSCPropNetProxiesHTTPSEnable as String)
            && host(kSCPropNetProxiesHTTPSProxy as String) == listenHost
            && proxyPort(kSCPropNetProxiesHTTPSPort as String) == port
            && isEnabled(kSCPropNetProxiesSOCKSEnable as String)
            && host(kSCPropNetProxiesSOCKSProxy as String) == listenHost
            && proxyPort(kSCPropNetProxiesSOCKSPort as String) == port
    }

    /// Writes the snapshotted proxy dictionaries back and removes the snapshot.
    /// Services that disappeared since apply() are skipped.
    static func restore() throws {
        let url = snapshotURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        guard let snapshot = readPlist(at: url) else {
            try? FileManager.default.removeItem(at: url)
            throw SystemProxyError.snapshotUnreadable
        }

        let preferences = SCPreferencesCreate(nil, "dev.tunguska.macos.helper" as CFString, nil)
        guard let preferences else {
            throw SystemProxyError.preferencesUnavailable
        }
        var services = try readServices(from: preferences)

        for (serviceID, proxies) in snapshot {
            guard var service = services[serviceID] else { continue }
            service[serviceProxiesKey] = proxies
            services[serviceID] = service
        }

        try commit(services, using: preferences)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Internals

    /// Reads the top-level network-services dictionary through the C shim.
    /// Swift cannot call SCPreferencesGetValue directly because it returns an
    /// untyped CFPropertyListRef.
    private static func readServices(from preferences: SCPreferences) throws -> [String: [String: Any]] {
        guard let dictionary = tunguska_SCPreferencesCopyServicesDictionary(
            preferences,
            kSCPrefNetworkServices as CFString
        ) else {
            throw SystemProxyError.servicesUnavailable
        }
        guard let services = dictionary as NSDictionary as? [String: [String: Any]] else {
            throw SystemProxyError.servicesUnavailable
        }
        return services
    }

    private static func proxySettings(port: Int, preserving existing: [String: Any]) -> [String: Any] {
        var proxies = existing
        proxies[kSCPropNetProxiesHTTPEnable as String] = 1
        proxies[kSCPropNetProxiesHTTPProxy as String] = HelperProtocol.proxyListenHost
        proxies[kSCPropNetProxiesHTTPPort as String] = port
        proxies[kSCPropNetProxiesHTTPSEnable as String] = 1
        proxies[kSCPropNetProxiesHTTPSProxy as String] = HelperProtocol.proxyListenHost
        proxies[kSCPropNetProxiesHTTPSPort as String] = port
        proxies[kSCPropNetProxiesSOCKSEnable as String] = 1
        proxies[kSCPropNetProxiesSOCKSProxy as String] = HelperProtocol.proxyListenHost
        proxies[kSCPropNetProxiesSOCKSPort as String] = port
        proxies[kSCPropNetProxiesProxyAutoConfigEnable as String] = 0
        proxies[kSCPropNetProxiesExceptionsList as String] = bypassDomains
        return proxies
    }

    private static func commit(
        _ services: [String: [String: Any]],
        using preferences: SCPreferences
    ) throws {
        guard SCPreferencesLock(preferences, true) else {
            throw SystemProxyError.commitFailed(lastErrorMessage(preferences))
        }
        defer { SCPreferencesUnlock(preferences) }

        guard SCPreferencesSetValue(
            preferences,
            kSCPrefNetworkServices as CFString,
            (services as NSDictionary) as CFDictionary
        ) else {
            throw SystemProxyError.commitFailed(lastErrorMessage(preferences))
        }
        guard SCPreferencesCommitChanges(preferences) else {
            throw SystemProxyError.commitFailed(lastErrorMessage(preferences))
        }
        // Push the committed setup into the running configuration immediately.
        _ = SCPreferencesApplyChanges(preferences)
        notifyProxiesChange()
    }

    /// Wakes long-running apps (browsers) so they re-read proxy settings right away,
    /// the same notification networksetup triggers.
    private static func notifyProxiesChange() {
        guard let store = SCDynamicStoreCreate(
            nil,
            "dev.tunguska.macos.helper" as CFString,
            nil,
            nil
        ) else { return }
        SCDynamicStoreNotifyValue(store, "Setup:/Network/Global/Proxies" as CFString)
    }

    private static func lastErrorMessage(_ preferences: SCPreferences) -> String {
        "error \(SCCopyLastError())"
    }

    private static func writePlist(_ value: [String: [String: Any]], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: value,
            format: .binary,
            options: 0
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func readPlist(at url: URL) -> [String: [String: Any]]? {
        guard let data = try? Data(contentsOf: url),
              let object = (try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              )) as? [String: [String: Any]]
        else { return nil }
        return object
    }
}
