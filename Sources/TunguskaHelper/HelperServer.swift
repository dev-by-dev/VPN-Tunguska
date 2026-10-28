import Foundation
import SystemConfiguration
import TunguskaCore

final class HelperServer: @unchecked Sendable {
    private let controller = SingBoxProcessController()
    private let acceptQueue = DispatchQueue(label: "dev.tunguska.macos.helper.accept")
    private let connectionQueue = DispatchQueue(label: "dev.tunguska.macos.helper.connection", attributes: .concurrent)

    func start() throws {
        try FileManager.default.createDirectory(
            at: HelperInstallation.rootDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: HelperInstallation.logDirectory,
            withIntermediateDirectories: true
        )

        let serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "Could not create the helper socket."]
            )
        }

        unlink(HelperProtocol.socketPath)

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(HelperProtocol.socketPath.utf8)
        let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < pathCapacity else {
            close(serverFD)
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(ENAMETOOLONG),
                userInfo: [NSLocalizedDescriptionKey: "The helper socket path is too long."]
            )
        }

        withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
            pathBytes.withUnsafeBytes { pathBuffer in
                rawBuffer.copyMemory(from: pathBuffer)
            }
            rawBuffer[pathBytes.count] = 0
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(serverFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            let errorCode = errno
            close(serverFD)
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errorCode),
                userInfo: [NSLocalizedDescriptionKey: "Could not bind the helper socket."]
            )
        }

        guard listen(serverFD, 8) == 0 else {
            let errorCode = errno
            close(serverFD)
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errorCode),
                userInfo: [NSLocalizedDescriptionKey: "Could not listen on the helper socket."]
            )
        }

        chmod(HelperProtocol.socketPath, 0o666)

        acceptQueue.async {
            self.acceptLoop(serverFD)
        }
    }

    private func acceptLoop(_ serverFD: Int32) {
        while true {
            let clientFD = accept(serverFD, nil, nil)
            if clientFD < 0 {
                if errno == EINTR {
                    continue
                }
                return
            }
            connectionQueue.async {
                self.handle(clientFD)
            }
        }
    }

    private func handle(_ clientFD: Int32) {
        defer { close(clientFD) }

        let response: HelperResponse
        if authorize(clientFD) {
            let requestData = readAll(clientFD)
            if let request = try? HelperProtocol.decodeRequest(requestData) {
                response = perform(request)
            } else {
                response = HelperResponse(
                    ok: false,
                    message: "The helper request is not valid JSON."
                )
            }
        } else {
            response = HelperResponse(
                ok: false,
                message: "The caller is not authorized to control the Tunguska helper."
            )
        }

        guard let responseData = try? HelperProtocol.encode(response) else {
            return
        }
        _ = responseData.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            return write(clientFD, baseAddress, responseData.count)
        }
    }

    private func perform(_ request: HelperRequest) -> HelperResponse {
        switch request.action {
        case .status:
            controller.status()
        case .start:
            controller.start(request: request)
        case .stop:
            controller.stop()
        }
    }

    private func authorize(_ clientFD: Int32) -> Bool {
        var peerUID: uid_t = 0
        var peerGID: gid_t = 0
        guard getpeereid(clientFD, &peerUID, &peerGID) == 0 else {
            return false
        }
        if peerUID == 0 {
            return true
        }

        var consoleUID: uid_t = 0
        let consoleUser = SCDynamicStoreCopyConsoleUser(nil, &consoleUID, nil)
        return consoleUser != nil && peerUID == consoleUID
    }

    private func readAll(_ fd: Int32) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)

        while true {
            let count = read(fd, &buffer, buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer[0 ..< count])
            } else {
                break
            }
        }
        return data
    }
}
