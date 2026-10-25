import Darwin
import Foundation
import Libbox
import Network
@preconcurrency import NetworkExtension

enum LibboxPlatformError: LocalizedError {
    case missingTunOptions
    case tunnelSettingsTimedOut
    case missingTunFileDescriptor
    case unsupportedConnectionOwner

    var errorDescription: String? {
        switch self {
        case .missingTunOptions:
            return "The embedded runtime requested TUN creation without options."
        case .tunnelSettingsTimedOut:
            return "Timed out while applying the tunnel network settings."
        case .missingTunFileDescriptor:
            return "The embedded runtime did not provide a utun file descriptor."
        case .unsupportedConnectionOwner:
            return "Connection-owner lookup is unavailable in a packet-tunnel app extension."
        }
    }
}

private final class EmptyNetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    func hasNext() -> Bool { false }
    func next() -> LibboxNetworkInterface? { nil }
}

private final class SettingsResult: @unchecked Sendable {
    var error: Error?
}

private final class InterfaceListenerBox: @unchecked Sendable {
    let listener: (any LibboxInterfaceUpdateListenerProtocol)?

    init(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) {
        self.listener = listener
    }
}

final class LibboxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, @unchecked Sendable {
    private let provider: NEPacketTunnelProvider
    private let monitorQueue = DispatchQueue(label: "dev.tunguska.macos.libbox.path-monitor")
    private let lock = NSLock()
    private var pathMonitor: NWPathMonitor?
    private var interfaceName: String?

    init(provider: NEPacketTunnelProvider) {
        self.provider = provider
        super.init()
    }

    func autoDetectControl(_ fd: Int32) throws {}

    func clearDNSCache() {}

    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        lock.lock()
        pathMonitor?.cancel()
        pathMonitor = nil
        lock.unlock()
    }

    func closeNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws {}

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw LibboxPlatformError.unsupportedConnectionOwner
    }

    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        EmptyNetworkInterfaceIterator()
    }

    func includeAllNetworks() -> Bool {
        false
    }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? {
        nil
    }

    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options, let ret0_ else {
            throw LibboxPlatformError.missingTunOptions
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: options.getMTU())

        let ipv4Addresses = Self.prefixes(options.getInet4Address())
        let ipv4Settings = NEIPv4Settings(
            addresses: ipv4Addresses.isEmpty ? ["172.19.0.1"] : ipv4Addresses.map(\.address),
            subnetMasks: ipv4Addresses.isEmpty ? ["255.255.255.252"] : ipv4Addresses.map(\.mask)
        )
        var ipv4IncludedRoutes = Self.ipv4Routes(options.getInet4RouteAddress())
        ipv4IncludedRoutes.append(contentsOf: Self.ipv4Routes(options.getInet4RouteRange()))
        if ipv4IncludedRoutes.isEmpty, options.getAutoRoute() {
            ipv4IncludedRoutes = [NEIPv4Route.default()]
        }
        ipv4Settings.includedRoutes = ipv4IncludedRoutes
        ipv4Settings.excludedRoutes = Self.ipv4Routes(options.getInet4RouteExcludeAddress())
        settings.ipv4Settings = ipv4Settings

        let ipv6Addresses = Self.prefixes(options.getInet6Address())
        if !ipv6Addresses.isEmpty {
            let ipv6Settings = NEIPv6Settings(
                addresses: ipv6Addresses.map(\.address),
                networkPrefixLengths: ipv6Addresses.map { NSNumber(value: $0.prefixLength) }
            )
            var ipv6IncludedRoutes = Self.ipv6Routes(options.getInet6RouteAddress())
            ipv6IncludedRoutes.append(contentsOf: Self.ipv6Routes(options.getInet6RouteRange()))
            if ipv6IncludedRoutes.isEmpty, options.getAutoRoute() {
                ipv6IncludedRoutes = [NEIPv6Route.default()]
            }
            ipv6Settings.includedRoutes = ipv6IncludedRoutes
            ipv6Settings.excludedRoutes = Self.ipv6Routes(options.getInet6RouteExcludeAddress())
            settings.ipv6Settings = ipv6Settings
        }

        if let dnsServer = try? options.getDNSServerAddress().value, !dnsServer.isEmpty {
            settings.dnsSettings = NEDNSSettings(servers: [dnsServer])
        }

        let semaphore = DispatchSemaphore(value: 0)
        let result = SettingsResult()
        provider.setTunnelNetworkSettings(settings) { error in
            result.error = error
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 15) == .success else {
            throw LibboxPlatformError.tunnelSettingsTimedOut
        }
        if let settingsError = result.error {
            throw settingsError
        }

        let fileDescriptor = LibboxGetTunnelFileDescriptor()
        guard fileDescriptor >= 0 else {
            throw LibboxPlatformError.missingTunFileDescriptor
        }
        ret0_.pointee = fileDescriptor
    }

    func readWIFIState() -> LibboxWIFIState? {
        nil
    }

    func registerMyInterface(_ name: String?) {
        lock.lock()
        interfaceName = name
        lock.unlock()
    }

    func send(_ notification: LibboxNotification?) throws {}

    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        let box = InterfaceListenerBox(listener)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            guard let first = path.availableInterfaces.first else {
                box.listener?.updateDefaultInterface(
                    nil,
                    interfaceIndex: 0,
                    isExpensive: path.isExpensive,
                    isConstrained: path.isConstrained
                )
                return
            }
            box.listener?.updateDefaultInterface(
                first.name,
                interfaceIndex: Int32(if_nametoindex(first.name)),
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained
            )
        }

        lock.lock()
        pathMonitor?.cancel()
        pathMonitor = monitor
        lock.unlock()
        monitor.start(queue: monitorQueue)
    }

    func startNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws {}

    func systemCertificates() -> (any LibboxStringIteratorProtocol)? {
        nil
    }

    func underNetworkExtension() -> Bool {
        true
    }

    func usePlatformAutoDetectControl() -> Bool {
        false
    }

    func useProcFS() -> Bool {
        false
    }

    private struct Prefix {
        let address: String
        let mask: String
        let prefixLength: Int

        var string: String {
            "\(address)/\(prefixLength)"
        }
    }

    private static func prefixes(_ iterator: (any LibboxRoutePrefixIteratorProtocol)?) -> [Prefix] {
        guard let iterator else { return [] }
        var result: [Prefix] = []
        while iterator.hasNext() {
            guard let prefix = iterator.next() else { break }
            result.append(
                Prefix(
                    address: prefix.address(),
                    mask: prefix.mask(),
                    prefixLength: Int(prefix.prefix())
                )
            )
        }
        return result
    }

    private static func ipv4Routes(_ iterator: (any LibboxRoutePrefixIteratorProtocol)?) -> [NEIPv4Route] {
        prefixes(iterator).map { NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask) }
    }

    private static func ipv6Routes(_ iterator: (any LibboxRoutePrefixIteratorProtocol)?) -> [NEIPv6Route] {
        prefixes(iterator).map {
            NEIPv6Route(
                destinationAddress: $0.address,
                networkPrefixLength: NSNumber(value: $0.prefixLength)
            )
        }
    }
}

final class LibboxCommandServerHandler: NSObject, LibboxCommandServerHandlerProtocol {
    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        status.available = false
        status.enabled = false
        return status
    }

    func serviceReload() throws {}

    func serviceStop() throws {}

    func setSystemProxyEnabled(_ enabled: Bool) throws {}

    func triggerNativeCrash() throws {}

    func writeDebugMessage(_ message: String?) {}
}
