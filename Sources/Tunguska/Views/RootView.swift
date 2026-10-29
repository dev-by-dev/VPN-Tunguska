import SwiftUI
import TunguskaCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedSection: AppModel.Section = {
        // Automated smoke-test hook: open -n Tunguska.app --args -open-section-profiles
        if ProcessInfo.processInfo.arguments.contains("-open-section-profiles") { return .profiles }
        if ProcessInfo.processInfo.arguments.contains("-open-section-settings") { return .settings }
        return .home
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
        .navigationTitle(settings.t(L10n.Key.appName))
    }

    private var sidebar: some View {
        List(AppModel.Section.allCases, selection: $selectedSection) { section in
            Label(settings.t(section.labelKey), systemImage: section.iconName)
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
        case .settings:
            SettingsView()
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: model.tunnelController.statusImageName)
                Text(settings.t(L10n.Key.appName))
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
                Text(settings.t(L10n.Key.commonNoProfileSelected))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if model.tunnelController.observedState == .connected {
                Text(
                    model.tunnelController.activeMode == .systemProxy
                        ? settings.fmt(L10n.Key.menubarSystemProxyFormat, HelperProtocol.proxyListenHost, HelperProtocol.defaultProxyPort)
                        : settings.t(L10n.Key.menubarTunMode)
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
                    model.tunnelController.observedState == .connected ? settings.t(L10n.Key.commonDisconnect) : settings.t(L10n.Key.commonConnect),
                    systemImage: model.tunnelController.observedState == .connected ? "stop.fill" : "play.fill"
                )
                .foregroundStyle(.primary)
            }
            .buttonStyle(MenuRowButtonStyle())
            .disabled(model.activeProfile == nil || model.tunnelController.isPreparing)

            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(settings.t(L10n.Key.menubarOpenApp), systemImage: "macwindow")
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
                Label(settings.t(L10n.Key.menubarQuitApp), systemImage: "power")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(MenuRowButtonStyle())
        }
        .padding(12)
        .frame(width: 280)
    }
}
