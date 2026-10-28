import Foundation
import TunguskaCore

final class SingBoxProcessController: @unchecked Sendable {
    struct Snapshot {
        var state: HelperRunState
        var pid: Int32?
        var interface: String?
        var startedAt: Date?
        var message: String?
    }

    private let lock = NSLock()
    private var process: Process?
    private var configPath: URL?
    private var startedAt: Date?
    private var lastMessage: String?

    init() {
        try? FileManager.default.createDirectory(
            at: HelperInstallation.runtimeDirectory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: HelperInstallation.logDirectory,
            withIntermediateDirectories: true
        )
    }

    func status() -> HelperResponse {
        lock.lock()
        defer { lock.unlock() }

        updateObservedInterfaceIfNeeded()
        return HelperResponse(ok: true, status: snapshotLocked().helperStatus, message: snapshotLocked().message)
    }

    func stop() -> HelperResponse {
        lock.lock()
        defer { lock.unlock() }

        stopLocked()
        lastMessage = "The tunnel service is stopped."
        return HelperResponse(ok: true, status: snapshotLocked().helperStatus, message: lastMessage)
    }

    func start(request: HelperRequest) -> HelperResponse {
        lock.lock()
        defer { lock.unlock() }

        guard let config = request.config, !config.isEmpty else {
            return HelperResponse(
                ok: false,
                status: snapshotLocked().helperStatus,
                message: "A sing-box configuration is required to start the tunnel."
            )
        }

        do {
            try HelperProtocol.validateStartConfiguration(config)
        } catch {
            return HelperResponse(
                ok: false,
                status: snapshotLocked().helperStatus,
                message: error.localizedDescription
            )
        }

        stopLocked()

        let expectedAddress = request.expectedInterfaceAddress ?? HelperProtocol.defaultTunAddress
        let configURL: URL
        do {
            configURL = try writeConfig(config)
        } catch {
            lastMessage = "Could not write the runtime configuration: \(error.localizedDescription)"
            return HelperResponse(ok: false, status: snapshotLocked().helperStatus, message: lastMessage)
        }

        let singBox = Process()
        singBox.executableURL = HelperInstallation.singBoxBinary
        singBox.arguments = ["run", "-c", configURL.path]

        do {
            let logURL = HelperInstallation.logDirectory.appendingPathComponent("sing-box.log")
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let logHandle = try FileHandle(forWritingTo: logURL)
            logHandle.seekToEndOfFile()
            singBox.standardOutput = logHandle
            singBox.standardError = logHandle
        } catch {
            lastMessage = "Could not open the sing-box log: \(error.localizedDescription)"
            return HelperResponse(ok: false, status: snapshotLocked().helperStatus, message: lastMessage)
        }

        singBox.terminationHandler = { [weak self] terminated in
            guard let self else { return }
            lock.lock()
            defer { lock.unlock() }
            guard process === terminated else { return }
            let reason: String
            switch terminated.terminationReason {
            case .exit:
                reason = "exit \(terminated.terminationStatus)"
            case .uncaughtSignal:
                reason = "signal \(terminated.terminationStatus)"
            @unknown default:
                reason = "termination \(terminated.terminationStatus)"
            }
            process = nil
            startedAt = nil
            lastMessage = "sing-box stopped (\(reason))."
        }

        do {
            try singBox.run()
        } catch {
            removeConfig(at: configURL)
            lastMessage = "Could not launch sing-box: \(error.localizedDescription)"
            return HelperResponse(ok: false, status: snapshotLocked().helperStatus, message: lastMessage)
        }

        process = singBox
        configPath = configURL
        startedAt = Date()
        lastMessage = "sing-box launched; waiting for the TUN interface."

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if !singBox.isRunning {
                break
            }
            if let interface = Self.observedInterface(expectedAddress: expectedAddress) {
                lastMessage = "Tunnel is running."
                return HelperResponse(ok: true, status: snapshotLocked(interface: interface).helperStatus, message: lastMessage)
            }
            usleep(100_000)
        }

        stopLocked()
        lastMessage = "sing-box started, but the expected TUN interface was not observed."
        return HelperResponse(ok: false, status: snapshotLocked().helperStatus, message: lastMessage)
    }

    private func writeConfig(_ config: String) throws -> URL {
        let temporaryURL = HelperInstallation.runtimeDirectory
            .appendingPathComponent(".config-\(UUID().uuidString).json")
        let targetURL = HelperInstallation.runtimeDirectory
            .appendingPathComponent("active-config.json")

        try config.write(to: temporaryURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: temporaryURL.path
        )
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
        return targetURL
    }

    private func removeConfig(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if configPath == url {
            configPath = nil
        }
    }

    private func stopLocked() {
        guard let running = process else {
            if let configPath {
                removeConfig(at: configPath)
            }
            startedAt = nil
            return
        }

        running.terminate()
        let deadline = Date().addingTimeInterval(3)
        while running.isRunning && Date() < deadline {
            usleep(50_000)
        }
        if running.isRunning {
            kill(running.processIdentifier, SIGKILL)
            running.waitUntilExit()
        }

        process = nil
        startedAt = nil
        if let configPath {
            removeConfig(at: configPath)
        }
    }

    private func updateObservedInterfaceIfNeeded() {
        guard process != nil else { return }
        if let interface = Self.observedInterface(expectedAddress: HelperProtocol.defaultTunAddress) {
            lastMessage = "Tunnel is running on \(interface)."
        }
    }

    private func snapshotLocked(interface: String? = nil) -> Snapshot {
        let pid = process?.processIdentifier
        let observed = interface ?? (process != nil
            ? Self.observedInterface(expectedAddress: HelperProtocol.defaultTunAddress)
            : nil)
        let state: HelperRunState
        if let process, process.isRunning {
            state = observed == nil ? .starting : .running
        } else {
            state = .stopped
        }
        return Snapshot(
            state: state,
            pid: pid,
            interface: observed,
            startedAt: startedAt,
            message: lastMessage
        )
    }

    private static func observedInterface(expectedAddress: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        var currentInterface: String?
        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Interface headers (e.g. "utun4: flags=...") start at column zero;
            // continuation lines (e.g. bridge "Configuration:") are indented.
            let isHeader = !line.hasPrefix("\t") && !line.hasPrefix(" ")
            if isHeader, let colon = line.firstIndex(of: ":"), colon > line.startIndex {
                let name = String(line[line.startIndex ..< colon])
                let isValidName = !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
                if isValidName {
                    currentInterface = name
                }
            } else if trimmed.hasPrefix("inet "), trimmed.contains(expectedAddress) {
                return currentInterface
            }
        }
        return nil
    }
}

private extension SingBoxProcessController.Snapshot {
    var helperStatus: HelperStatus {
        HelperStatus(
            state: state,
            pid: pid.map { Int($0) },
            interface: interface,
            startedAt: startedAt,
            message: message
        )
    }
}
