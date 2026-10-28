import Foundation
import os

struct TrafficSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let downBytesPerSecond: Double
    let upBytesPerSecond: Double
}

enum TrafficFormat {
    static func rate(_ bytesPerSecond: Double) -> String {
        let value = max(bytesPerSecond, 0)
        switch value {
        case ..<1_024: String(format: "%.0f B/s", value)
        case ..<1_048_576: String(format: "%.1f KB/s", value / 1_024)
        case ..<1_073_741_824: String(format: "%.1f MB/s", value / 1_048_576)
        default: String(format: "%.2f GB/s", value / 1_073_741_824)
        }
    }

    static func total(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }
}

/// Samples per-interface byte counters once per second while the VPN is connected
/// and publishes a rolling window of rates plus session totals for the Home charts.
@MainActor
final class TrafficMonitor: ObservableObject {
    @Published private(set) var samples: [TrafficSample] = []
    @Published private(set) var totalDownBytes: UInt64 = 0
    @Published private(set) var totalUpBytes: UInt64 = 0
    @Published private(set) var isActive = false
    @Published private(set) var sessionStartedAt: Date?

    private static let logger = Logger(subsystem: "dev.tunguska.macos", category: "traffic")
    private static let windowSize = 120

    private var sampler: Task<Void, Never>?
    private var activeInterface: String?
    private var lastDownBytes: UInt64?
    private var lastUpBytes: UInt64?
    private var lastSampleDate: Date?

    var currentDownBytesPerSecond: Double { samples.last?.downBytesPerSecond ?? 0 }
    var currentUpBytesPerSecond: Double { samples.last?.upBytesPerSecond ?? 0 }

    func start(interface: String) {
        guard !(isActive && activeInterface == interface) else { return }
        stop()
        samples = []
        totalDownBytes = 0
        totalUpBytes = 0
        lastDownBytes = nil
        lastUpBytes = nil
        lastSampleDate = nil
        activeInterface = interface
        sessionStartedAt = Date()
        isActive = true
        Self.logger.log("traffic sampling started on \(interface, privacy: .public)")
        sampler = Task { [weak self] in
            await self?.runSampler(on: interface)
        }
    }

    func stop() {
        sampler?.cancel()
        sampler = nil
        if isActive {
            Self.logger.log(
                "traffic sampling stopped (down=\(self.totalDownBytes, privacy: .public) up=\(self.totalUpBytes, privacy: .public))"
            )
        }
        isActive = false
        activeInterface = nil
    }

    private func runSampler(on interface: String) async {
        while !Task.isCancelled {
            if let counters = await Self.readCounters(interface: interface) {
                apply(down: counters.down, up: counters.up, at: counters.date)
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func apply(down: UInt64, up: UInt64, at date: Date) {
        defer {
            lastDownBytes = down
            lastUpBytes = up
            lastSampleDate = date
        }
        guard let previousDown = lastDownBytes,
              let previousUp = lastUpBytes,
              let previousDate = lastSampleDate
        else { return }

        let interval = max(date.timeIntervalSince(previousDate), 0.05)
        let downDelta = down > previousDown ? down - previousDown : 0
        let upDelta = up > previousUp ? up - previousUp : 0
        totalDownBytes += downDelta
        totalUpBytes += upDelta
        samples.append(
            TrafficSample(
                date: date,
                downBytesPerSecond: Double(downDelta) / interval,
                upBytesPerSecond: Double(upDelta) / interval
            )
        )
        if samples.count > Self.windowSize {
            samples.removeFirst(samples.count - Self.windowSize)
        }
    }

    /// Reads link-level interface counters via netstat. Link rows look like:
    /// `utun4 9000 <Link#21> Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll`
    private static func readCounters(interface: String) async -> (down: UInt64, up: UInt64, date: Date)? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
            process.arguments = ["-ibn", "-I", interface]
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
            else { return nil }

            for line in output.split(separator: "\n") {
                let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
                guard fields.count >= 10,
                      fields[2].hasPrefix("<Link#"),
                      let inBytes = UInt64(fields[5]),
                      let outBytes = UInt64(fields[8])
                else { continue }
                return (inBytes, outBytes, Date())
            }
            return nil
        }.value
    }
}
