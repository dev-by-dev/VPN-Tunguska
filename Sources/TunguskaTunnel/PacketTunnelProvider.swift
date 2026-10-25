import Foundation
import Libbox
@preconcurrency import NetworkExtension
import TunguskaCore

enum PacketTunnelProviderError: LocalizedError {
    case missingRuntimeRequest
    case profileNotFound(String)
    case configurationFailed(String)
    case runtimeSetupFailed(String)
    case runtimeStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRuntimeRequest:
            return "The tunnel request does not contain the profile identifier required to resolve the Keychain profile."
        case .profileNotFound(let id):
            return "The sealed profile \(id) could not be found in the shared Keychain."
        case .configurationFailed(let message):
            return "The sing-box configuration could not be generated: \(message)"
        case .runtimeSetupFailed(let message):
            return "The embedded sing-box runtime could not be initialized: \(message)"
        case .runtimeStartFailed(let message):
            return "The embedded sing-box runtime could not start: \(message)"
        }
    }
}

struct PacketTunnelRuntimeRequest: Equatable {
    let profileID: String
    let serverAddress: String
}

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var platformInterface: LibboxPlatformInterface?
    private var commandServer: LibboxCommandServer?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        do {
            let request = try Self.runtimeRequest(from: protocolConfiguration)
            guard let profile = try ProfileKeychainStore.shared.loadProfile(id: request.profileID) else {
                throw PacketTunnelProviderError.profileNotFound(request.profileID)
            }

            let generated: SingBoxGeneratedConfiguration
            do {
                generated = try SingBoxConfigurationBuilder.build(profile: profile)
            } catch {
                throw PacketTunnelProviderError.configurationFailed(error.localizedDescription)
            }

            try startRuntime(configContent: generated.json)
            completionHandler(nil)
        } catch {
            finishRuntime()
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        finishRuntime()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let response: [String: String] = [
            "runtime": "sing-box",
            "status": commandServer == nil ? "stopped" : "running",
        ]
        completionHandler?(try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]))
    }

    private func startRuntime(configContent: String) throws {
        finishRuntime()

        let paths = try Self.runtimePaths()
        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = paths.base.path
        setupOptions.workingPath = paths.working.path
        setupOptions.tempPath = paths.temp.path
        setupOptions.fixAndroidStack = false
        setupOptions.commandServerListenPort = 0
        setupOptions.commandServerSecret = ""
        setupOptions.logMaxLines = 200
        setupOptions.debug = false
        setupOptions.crashReportSource = "TunguskaTunnel"
        setupOptions.oomKillerEnabled = false
        setupOptions.oomKillerDisabled = true
        setupOptions.oomMemoryLimit = 0

        if !LibboxSetup(setupOptions, nil) {
            throw PacketTunnelProviderError.runtimeSetupFailed("LibboxSetup returned false.")
        }

        let platform = LibboxPlatformInterface(provider: self)
        let handler = LibboxCommandServerHandler()
        let server: LibboxCommandServer?
        server = LibboxNewCommandServer(handler, platform, nil)
        guard let server else {
            throw PacketTunnelProviderError.runtimeSetupFailed("LibboxNewCommandServer returned no server.")
        }

        platformInterface = platform
        commandServer = server

        do {
            try server.start()
            try server.startOrReloadService(configContent, options: nil)
        } catch {
            throw PacketTunnelProviderError.runtimeStartFailed(error.localizedDescription)
        }
    }

    private func finishRuntime() {
        if let commandServer {
            _ = try? commandServer.closeService()
            commandServer.close()
        }
        commandServer = nil
        platformInterface = nil
    }

    private static func runtimePaths() throws -> (base: URL, working: URL, temp: URL) {
        let fileManager = FileManager.default
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let base = root.appendingPathComponent("dev.tunguska.macos", isDirectory: true)
        let working = base.appendingPathComponent("working", isDirectory: true)
        let temp = base.appendingPathComponent("temp", isDirectory: true)

        try fileManager.createDirectory(at: working, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)
        return (base, working, temp)
    }

    private static func runtimeRequest(from configuration: NEVPNProtocol?) throws -> PacketTunnelRuntimeRequest {
        guard let configuration = configuration as? NETunnelProviderProtocol,
              let providerConfiguration = configuration.providerConfiguration,
              let profileID = providerConfiguration["profileID"] as? String,
              let serverAddress = providerConfiguration["serverAddress"] as? String,
              !profileID.isEmpty,
              !serverAddress.isEmpty else {
            throw PacketTunnelProviderError.missingRuntimeRequest
        }
        return PacketTunnelRuntimeRequest(profileID: profileID, serverAddress: serverAddress)
    }
}
