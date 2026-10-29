import Charts
import SwiftUI
import TunguskaCore

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
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
        .alert(settings.t(L10n.Key.homeTunnelErrorTitle), isPresented: Binding(
            get: { model.tunnelError != nil },
            set: { if !$0 { model.clearTunnelError() } }
        )) {
            Button(settings.t(L10n.Key.commonOK), role: .cancel) {}
        } message: {
            Text(model.tunnelError ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.t(L10n.Key.appName).uppercased())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(2)
                Text(settings.t(L10n.Key.homeTagline))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(state: model.tunnelController.observedState)
        }
    }

    private var connectionPanel: some View {
        PanelCard(title: settings.t(L10n.Key.homeConnection), systemImage: "gauge.with.needle") {
            HStack(alignment: .center, spacing: 24) {
                stateGlyph
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(stateColor)
                    .frame(width: 72, height: 72)
                    .background(stateColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.activeProfile?.name ?? settings.t(L10n.Key.commonNoProfileSelected))
                        .font(.title2.weight(.semibold))
                    Text(model.activeProfile?.endpointSummary ?? settings.t(L10n.Key.homeImportProfileHint))
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                    Text(model.tunnelController.observedState.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Picker(settings.t(L10n.Key.homeMode), selection: $selectedMode) {
                        Text(settings.t(L10n.Key.homeModeTun)).tag(HelperCommandMode.tun)
                        Text(settings.t(L10n.Key.homeModeSystemProxy)).tag(HelperCommandMode.systemProxy)
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
                            ? settings.t(L10n.Key.homeHelpTun)
                            : settings.fmt(
                                L10n.Key.homeHelpSystemProxy,
                                HelperProtocol.proxyListenHost,
                                HelperProtocol.defaultProxyPort
                            )
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
                        Text(model.activeProfile?.name ?? settings.t(L10n.Key.commonNoProfile))
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
                            model.tunnelController.observedState == .connected ? settings.t(L10n.Key.commonDisconnect) : settings.t(L10n.Key.homeStartVPN),
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
        PanelCard(title: settings.t(L10n.Key.homeTraffic), systemImage: "chart.xyaxis.line") {
            TrafficPanelContent(
                traffic: model.tunnelController.traffic,
                isConnected: model.tunnelController.observedState == .connected
            )
        }
    }

    private var configurationPanels: some View {
        HStack(alignment: .top, spacing: 16) {
            PanelCard(title: settings.t(L10n.Key.homeTunnelScope), systemImage: "network") {
                if let profile = model.activeProfile {
                    LabeledContent(settings.t(L10n.Key.homeMode), value: splitTunnelTitle(profile.vpn.splitTunnel))
                    LabeledContent(
                        settings.t(L10n.Key.homePackages),
                        value: profile.vpn.splitTunnel.packageNames.isEmpty
                            ? settings.t(L10n.Key.homeAllApplications)
                            : settings.fmt(L10n.Key.homeIdentifiersFormat, profile.vpn.splitTunnel.packageNames.count)
                    )
                    LabeledContent(settings.t(L10n.Key.homeDnsLabel), value: dnsModeTitle(profile.dns))
                } else {
                    Text(settings.t(L10n.Key.commonNoProfileSelected))
                        .foregroundStyle(.secondary)
                }
            }

            PanelCard(title: settings.t(L10n.Key.sidebarRouting), systemImage: "arrow.triangle.branch") {
                if let profile = model.activeProfile {
                    LabeledContent(settings.t(L10n.Key.commonDefault), value: profile.routing.defaultAction.rawValue)
                    LabeledContent(settings.t(L10n.Key.homeRoutingRules), value: "\(profile.routing.rules.count)")
                    LabeledContent(
                        settings.t(L10n.Key.homeRegionalBypass),
                        value: profile.routing.regionalBypass.enabledPresets.isEmpty
                            ? settings.t(L10n.Key.commonOff)
                            : profile.routing.regionalBypass.enabledPresets.map { $0.rawValue }.joined(separator: ", ")
                    )
                } else {
                    Text(settings.t(L10n.Key.commonNoProfileSelected))
                        .foregroundStyle(.secondary)
                }
            }

            PanelCard(title: settings.t(L10n.Key.homeSafetyPanel), systemImage: "lock.shield") {
                if let profile = model.activeProfile {
                    LabeledContent(settings.t(L10n.Key.commonSafeMode), value: profile.safety.safeMode ? settings.t(L10n.Key.commonOn) : settings.t(L10n.Key.commonOff))
                    LabeledContent(settings.t(L10n.Key.commonLocalProxy), value: profile.safety.compatibilityLocalProxy ? settings.t(L10n.Key.commonEnabled) : settings.t(L10n.Key.commonDisabled))
                    LabeledContent(settings.t(L10n.Key.commonDebugEndpoints), value: profile.safety.debugEndpointsEnabled ? settings.t(L10n.Key.commonEnabled) : settings.t(L10n.Key.commonDisabled))
                } else {
                    Text(settings.t(L10n.Key.commonNoProfileSelected))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var runtimeIntegrityPanel: some View {
        PanelCard(title: settings.t(L10n.Key.homeRuntimeIntegrity), systemImage: "checkmark.shield") {
            VStack(alignment: .leading, spacing: 8) {
                Label(settings.t(L10n.Key.homeIntegrityConnectedUI), systemImage: "network.badge.shield.half.filled")
                Label(settings.t(L10n.Key.homeIntegrityLoopback), systemImage: "arrow.clockwise")
                Label(settings.t(L10n.Key.homeIntegritySecrets), systemImage: "key.fill")
                Label(settings.t(L10n.Key.homeIntegrityHelper), systemImage: "shippingbox")
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
        case .fullTunnel: settings.t(L10n.Key.homeSplitTunnelFull)
        case .allowlist: settings.t(L10n.Key.homeSplitTunnelAllowlist)
        case .denylist: settings.t(L10n.Key.homeSplitTunnelDenylist)
        }
    }

    private func dnsModeTitle(_ mode: DnsMode) -> String {
        switch mode {
        case let .vpnDns(servers): settings.fmt(L10n.Key.homeDnsVpnFormat, servers.count)
        case .systemDns: settings.t(L10n.Key.commonSystemDns)
        case let .customEncrypted(kind, endpoints): settings.fmt(L10n.Key.homeDnsCustomFormat, kind.rawValue, endpoints.count)
        }
    }
}

private struct TrafficPanelContent: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var traffic: TrafficMonitor
    let isConnected: Bool

    var body: some View {
        if isConnected && traffic.isActive {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    trafficStat(
                        title: settings.t(L10n.Key.homeTrafficDown),
                        color: .blue,
                        rate: TrafficFormat.rate(traffic.currentDownBytesPerSecond),
                        total: TrafficFormat.total(traffic.totalDownBytes)
                    )
                    trafficStat(
                        title: settings.t(L10n.Key.homeTrafficUp),
                        color: .green,
                        rate: TrafficFormat.rate(traffic.currentUpBytesPerSecond),
                        total: TrafficFormat.total(traffic.totalUpBytes)
                    )
                    Spacer()
                    if let startedAt = traffic.sessionStartedAt {
                        Text("\(settings.t(L10n.Key.homeSession)) \(startedAt, style: .relative)")
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
            Text(settings.t(L10n.Key.homeTrafficEmpty))
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
                Text(settings.fmt(L10n.Key.homeTrafficTotal, total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
