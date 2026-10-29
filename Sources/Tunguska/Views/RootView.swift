import SwiftUI
import TunguskaCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedSection: AppModel.Section = {
        // Automated smoke-test hook: open -n Tunguska.app --args -open-section-profiles
        ProcessInfo.processInfo.arguments.contains("-open-section-profiles") ? .profiles : .home
    }()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
        }
        .navigationTitle("Tunguska")
    }

    private var sidebar: some View {
        List(AppModel.Section.allCases, selection: $selectedSection) { section in
            Label(section.rawValue, systemImage: section.iconName)
                .tag(section)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .home:
            HomeView()
        case .profiles:
            ProfilesView()
        case .routing:
            RoutingView()
        case .security:
            SecurityView()
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: model.tunnelController.statusImageName)
                Text("Tunguska")
                    .font(.headline)
                Spacer()
                StatusPill(state: model.tunnelController.observedState)
            }

            if let profile = model.activeProfile {
                Text(profile.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(profile.endpointSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text("No profile selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if model.tunnelController.observedState == .connected {
                Text(
                    model.tunnelController.activeMode == .systemProxy
                        ? "System proxy · \(HelperProtocol.proxyListenHost):\(HelperProtocol.defaultProxyPort)"
                        : "TUN mode"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

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
                    model.tunnelController.observedState == .connected ? "Disconnect" : "Connect",
                    systemImage: model.tunnelController.observedState == .connected ? "stop.fill" : "play.fill"
                )
                .foregroundStyle(.primary)
            }
            .buttonStyle(MenuRowButtonStyle())
            .disabled(model.activeProfile == nil || model.tunnelController.isPreparing)

            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Tunguska", systemImage: "macwindow")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(MenuRowButtonStyle())

            if let tunnelError = model.tunnelError {
                Text(tunnelError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button {
                model.quitFromMenuBar()
            } label: {
                Label("Quit Tunguska", systemImage: "power")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(MenuRowButtonStyle())
        }
        .padding(12)
        .frame(width: 280)
    }
}
