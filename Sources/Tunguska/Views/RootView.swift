import SwiftUI

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

            Divider()

            Button(model.tunnelController.observedState == .connected ? "Disconnect" : "Connect") {
                Task {
                    if model.tunnelController.observedState == .connected {
                        await model.disconnectTunnel()
                    } else {
                        await model.connectActiveProfile()
                    }
                }
            }
            .disabled(model.activeProfile == nil || model.tunnelController.isPreparing)

            Button("Open Tunguska") {
                NSApp.activate(ignoringOtherApps: true)
            }

            if let tunnelError = model.tunnelError {
                Text(tunnelError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Quit Tunguska", role: .destructive) {
                model.quitFromMenuBar()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(12)
        .frame(width: 280)
    }
}
