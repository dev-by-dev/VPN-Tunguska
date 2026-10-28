import Darwin
import Foundation
import TunguskaCore

enum HelperClientError: LocalizedError {
    case socketUnavailable(String)
    case requestFailed(String)
    case emptyResponse
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .socketUnavailable(message),
             let .requestFailed(message):
            return message
        case .emptyResponse:
            return "The Tunguska helper closed the connection without a response."
        case .invalidResponse:
            return "The Tunguska helper returned an unreadable response."
        }
    }
}

struct HelperClient {
    func send(_ request: HelperRequest) async throws -> HelperResponse {
        try await Task.detached(priority: .userInitiated) {
            try Self.sendSynchronously(request)
        }.value
    }

    private static func sendSynchronously(_ request: HelperRequest) throws -> HelperResponse {
        let requestData = try HelperProtocol.encode(request)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw HelperClientError.socketUnavailable("Could not create a local helper socket.")
        }
        defer { close(fd) }

        var noSignalPipe: Int32 = 1
        setsockopt(
            fd,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSignalPipe,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(HelperProtocol.socketPath.utf8)
        let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < pathCapacity else {
            throw HelperClientError.socketUnavailable("The helper socket path is too long.")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
            pathBytes.withUnsafeBytes { pathBuffer in
                rawBuffer.copyMemory(from: pathBuffer)
            }
            rawBuffer[pathBytes.count] = 0
        }

        let connectResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            let message: String
            switch errno {
            case ENOENT:
                message = "The Tunguska privileged service is not installed. Run scripts/install-helper.sh first."
            case EACCES:
                message = "macOS denied access to the Tunguska privileged service."
            default:
                message = String(cString: strerror(errno))
            }
            throw HelperClientError.socketUnavailable(message)
        }

        try writeAll(requestData, to: fd)
        shutdown(fd, SHUT_WR)

        let responseData = try readAll(from: fd)
        guard !responseData.isEmpty else {
            throw HelperClientError.emptyResponse
        }
        do {
            return try HelperProtocol.decodeResponse(responseData)
        } catch {
            throw HelperClientError.invalidResponse
        }
    }

    private static func writeAll(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.send(fd, baseAddress.advanced(by: offset), buffer.count - offset, 0)
                if written < 0 {
                    if errno == EINTR {
                        continue
                    }
                    throw HelperClientError.requestFailed("Could not send the helper request: \(String(cString: strerror(errno)))")
                }
                offset += written
            }
        }
    }

    private static func readAll(from fd: Int32) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)

        while true {
            let count = read(fd, &buffer, buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer[0 ..< count])
            } else if count == 0 {
                break
            } else if errno != EINTR {
                throw HelperClientError.requestFailed("Could not read the helper response: \(String(cString: strerror(errno)))")
            }
        }
        return data
    }
}
