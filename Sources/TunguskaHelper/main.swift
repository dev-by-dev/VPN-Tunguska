import Darwin
import Foundation

signal(SIGTERM) { _ in
    exit(0)
}
signal(SIGINT) { _ in
    exit(0)
}

do {
    try HelperServer().start()
} catch {
    FileHandle.standardError.write(Data("Tunguska helper failed to start: \(error.localizedDescription)\n".utf8))
    exit(1)
}

dispatchMain()
