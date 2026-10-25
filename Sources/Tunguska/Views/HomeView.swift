import SwiftUI
import TunguskaCore

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                connectionPanel
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
                    Picker("Profile", selection: model.activeProfileBinding) {
                        Text("No profile").tag("")
                        ForEach(model.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 240)

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
                Label("Connected UI state requires a live NetworkExtension session.", systemImage: "network.badge.shield.half.filled")
                Label("Loopback traffic remains local by policy.", systemImage: "arrow.loopback")
                Label("Profile secrets are read from Keychain storage, not UserDefaults or logs.", systemImage: "key.fill")
                Label("The arm64 tunnel target links the pinned libbox runtime; starting it requires a Team-signed NetworkExtension host.", systemImage: "shippingbox")
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
