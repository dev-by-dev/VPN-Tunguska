import Charts
import SwiftUI
import TunguskaCore

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedMode: HelperCommandMode = .tun

    private var isSessionActive: Bool {
        switch model.tunnelController.observedState {
        case .connected, .connecting, .disconnecting:
            true
        default:
            false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                connectionPanel
                trafficPanel
                configurationPanels
                runtimeIntegrityPanel
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .alert("Tunnel error", isPresented: Binding(
            get: { model.tunnelError != nil },
            set: { if !$0 { model.clearTunnelError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.tunnelError ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TUNGUSKA")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(2)
                Text("Native Apple Silicon VLESS + REALITY client")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(state: model.tunnelController.observedState)
        }
    }

    private var connectionPanel: some View {
        PanelCard(title: "Connection", systemImage: "gauge.with.needle") {
            HStack(alignment: .center, spacing: 24) {
                stateGlyph
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(stateColor)
                    .frame(width: 72, height: 72)
                    .background(stateColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.activeProfile?.name ?? "No profile selected")
                        .font(.title2.weight(.semibold))
                    Text(model.activeProfile?.endpointSummary ?? "Import a VLESS + REALITY profile to prepare the tunnel.")
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                    Text(model.tunnelController.observedState.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Picker("Mode", selection: $selectedMode) {
                        Text("TUN").tag(HelperCommandMode.tun)
                        Text("System Proxy").tag(HelperCommandMode.systemProxy)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .disabled(isSessionActive || model.tunnelController.isPreparing)
                    .onAppear {
                        selectedMode = model.tunnelMode
                    }
                    .onChange(of: model.tunnelMode) { _, newValue in
                        if selectedMode != newValue {
                            selectedMode = newValue
                        }
                    }
                    .onChange(of: selectedMode) { _, newValue in
                        model.setTunnelMode(newValue)
                    }
                    .help(
                        selectedMode == .tun
                            ? "TUN mode captures all system traffic through a virtual interface."
                            : "System Proxy mode routes apps that honor the macOS proxy settings through 127.0.0.1:\(HelperProtocol.defaultProxyPort)."
                    )

                    Menu {
                        ForEach(model.profiles) { profile in
                            Button {
                                model.selectProfile(id: profile.id)
                            } label: {
                                Label(
                                    profile.name,
                                    systemImage: profile.id == model.activeProfileID ? "checkmark" : ""
                                )
                            }
                        }
                    } label: {
                        Text(model.activeProfile?.name ?? "No profile")
                            .frame(width: 200, alignment: .trailing)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button {
                        Task {
                            if model.tunnelController.observedState == .connected {
                                await model.disconnectTunnel()
                            } else {
                                await model.connectActiveProfile()
                            }
                        }
                    } label: {
                        Label(
                            model.tunnelController.observedState == .connected ? "Disconnect" : "Start VPN",
                            systemImage: model.tunnelController.observedState == .connected ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.activeProfile == nil || model.tunnelController.isPreparing)
                }
            }
        }
    }

    private var trafficPanel: some View {
        PanelCard(title: "Traffic", systemImage: "chart.xyaxis.line") {
            TrafficPanelContent(
                traffic: model.tunnelController.traffic,
                isConnected: model.tunnelController.observedState == .connected
            )
        }
    }

    private var configurationPanels: some View {
        HStack(alignment: .top, spacing: 16) {
            PanelCard(title: "Tunnel scope", systemImage: "network") {
                if let profile = model.activeProfile {
                    LabeledContent("Mode", value: splitTunnelTitle(profile.vpn.splitTunnel))
                    LabeledContent("Packages", value: profile.vpn.splitTunnel.packageNames.isEmpty ? "All applications" : "\(profile.vpn.splitTunnel.packageNames.count) identifiers")
                    LabeledContent("DNS", value: dnsModeTitle(profile.dns))
                } else {
                    Text("No profile selected")
                        .foregroundStyle(.secondary)
                }
            }

            PanelCard(title: "Routing", systemImage: "arrow.triangle.branch") {
                if let profile = model.activeProfile {
                    LabeledContent("Default", value: profile.routing.defaultAction.rawValue)
                    LabeledContent("Rules", value: "\(profile.routing.rules.count)")
                    LabeledContent("Regional bypass", value: profile.routing.regionalBypass.enabledPresets.isEmpty ? "Off" : profile.routing.regionalBypass.enabledPresets.map { $0.rawValue }.joined(separator: ", "))
                } else {
                    Text("No profile selected")
                        .foregroundStyle(.secondary)
                }
            }

            PanelCard(title: "Safety", systemImage: "lock.shield") {
                if let profile = model.activeProfile {
                    LabeledContent("Safe mode", value: profile.safety.safeMode ? "On" : "Off")
                    LabeledContent("Local proxy", value: profile.safety.compatibilityLocalProxy ? "Enabled" : "Disabled")
                    LabeledContent("Debug endpoints", value: profile.safety.debugEndpointsEnabled ? "Enabled" : "Disabled")
                } else {
                    Text("No profile selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var runtimeIntegrityPanel: some View {
        PanelCard(title: "Runtime integrity", systemImage: "checkmark.shield") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Connected UI state requires a live TUN interface from the privileged service.", systemImage: "network.badge.shield.half.filled")
                Label("Loopback traffic remains local by policy.", systemImage: "arrow.clockwise")
                Label("Profile secrets are read from Keychain storage, not UserDefaults or logs.", systemImage: "key.fill")
                Label("The Clash-Verge-style arm64 helper starts a pinned sing-box CLI and owns routes/DNS.", systemImage: "shippingbox")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var stateGlyph: some View {
        Image(systemName: model.tunnelController.statusImageName)
    }

    private var stateColor: Color {
        switch model.tunnelController.observedState {
        case .connected: .green
        case .connecting, .disconnecting: .orange
        case .failed: .red
        case .disconnected, .unavailable: .secondary
        }
    }

    private func splitTunnelTitle(_ mode: SplitTunnelMode) -> String {
        switch mode {
        case .fullTunnel: "Full tunnel"
        case .allowlist: "Allowlist"
        case .denylist: "Denylist"
        }
    }

    private func dnsModeTitle(_ mode: DnsMode) -> String {
        switch mode {
        case let .vpnDns(servers): "VPN DNS (\(servers.count))"
        case .systemDns: "System DNS"
        case let .customEncrypted(kind, endpoints): "Encrypted DNS \(kind.rawValue) (\(endpoints.count))"
        }
    }
}

private struct TrafficPanelContent: View {
    @ObservedObject var traffic: TrafficMonitor
    let isConnected: Bool

    var body: some View {
        if isConnected && traffic.isActive {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    trafficStat(
                        title: "Down",
                        color: .blue,
                        rate: TrafficFormat.rate(traffic.currentDownBytesPerSecond),
                        total: TrafficFormat.total(traffic.totalDownBytes)
                    )
                    trafficStat(
                        title: "Up",
                        color: .green,
                        rate: TrafficFormat.rate(traffic.currentUpBytesPerSecond),
                        total: TrafficFormat.total(traffic.totalUpBytes)
                    )
                    Spacer()
                    if let startedAt = traffic.sessionStartedAt {
                        Text("Session \(startedAt, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Chart(traffic.samples) { sample in
                    AreaMark(
                        x: .value("Time", sample.date),
                        y: .value("Down", Int64(sample.downBytesPerSecond.rounded()))
                    )
                    .foregroundStyle(Color.blue.opacity(0.30))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", sample.date),
                        y: .value("Up", Int64(sample.upBytesPerSecond.rounded()))
                    )
                    .foregroundStyle(Color.green.opacity(0.30))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { AxisValueLabel(format: .byteCount(style: .file)) }
                }
                .frame(height: 130)
            }
        } else {
            Text("Connect the VPN to see live speed, session traffic, and volume totals.")
                .foregroundStyle(.secondary)
        }
    }

    private func trafficStat(title: String, color: Color, rate: String, total: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rate)
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text("\(total) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
