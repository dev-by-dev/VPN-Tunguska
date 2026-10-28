import SwiftUI
import TunguskaCore

struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            profileList
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 380)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    importPanel
                    if let profile = model.activeProfile {
                        ProfileDetailView(profile: profile)
                    } else {
                        PanelCard(title: "Profile", systemImage: "rectangle.on.rectangle") {
                            Text("Select or import a profile.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 820, alignment: .leading)
            }
        }
        .navigationTitle("Profiles")
    }

    private var profileList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profiles")
                .font(.title2.weight(.semibold))
                .padding([.top, .horizontal], 14)

            List {
                ForEach(model.profiles) { profile in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.headline)
                            Text(profile.endpointSummary)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if profile.id == model.activeProfileID {
                            Label("Active", systemImage: "checkmark.seal.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.green)
                        } else {
                            Button("Select") {
                                model.selectProfile(id: profile.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectProfile(id: profile.id)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            model.deleteProfile(id: profile.id)
                        }
                    }
                }
            }
            .listStyle(.inset)

            if let storageError = model.storageError {
                InlineMessage(text: storageError, tone: .error)
                    .padding(.horizontal)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var importPanel: some View {
        PanelCard(title: "Staged import", systemImage: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $model.importText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                HStack {
                    Button("Validate Import") {
                        model.stageImport()
                    }
                    .disabled(model.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Discard", role: .cancel) {
                        model.discardImport()
                        model.importText = ""
                    }
                    .disabled(model.importPreview == nil && model.importError == nil)

                    Spacer()

                    Text("Import never auto-connects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let importError = model.importError {
                    InlineMessage(text: importError, tone: .error)
                }

                if let preview = model.importPreview {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(preview.source.summary, systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                        LabeledContent("Name", value: preview.profile.name)
                        LabeledContent("Endpoint", value: preview.profile.endpointSummary)
                        LabeledContent("Flow", value: preview.profile.outbound.flow ?? "Default")
                        LabeledContent("SNI", value: preview.profile.outbound.serverName)

                        ForEach(preview.warnings, id: \.self) { warning in
                            InlineMessage(text: warning, tone: .warning)
                        }

                        HStack {
                            Button("Save to Keychain") {
                                model.confirmImport()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Discard Preview", role: .cancel) {
                                model.discardImport()
                            }
                        }
                    }
                    .padding(12)
                    .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

struct ProfileDetailView: View {
    let profile: ProfileIr

    var body: some View {
        PanelCard(title: "Active profile", systemImage: "rectangle.on.rectangle") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Name", value: profile.name)
                LabeledContent("Endpoint", value: profile.endpointSummary)
                LabeledContent("Flow", value: profile.outbound.flow ?? "Default")
                LabeledContent("uTLS", value: profile.outbound.utlsFingerprint)
                LabeledContent("Spider X", value: profile.outbound.effectiveRealitySpiderX)
                LabeledContent("SNI", value: profile.outbound.serverName)

                Divider()

                LabeledContent("UUID", value: maskedSecret(profile.outbound.uuid))
                LabeledContent("REALITY public key", value: maskedSecret(profile.outbound.realityPublicKey))
                LabeledContent("REALITY short id", value: maskedSecret(profile.outbound.realityShortId))

                Divider()

                LabeledContent("DNS", value: dnsTitle)
                LabeledContent("Safe mode", value: profile.safety.safeMode ? "On" : "Off")
                LabeledContent("Local proxy", value: profile.safety.compatibilityLocalProxy ? "Enabled" : "Disabled")
                LabeledContent("Debug endpoints", value: profile.safety.debugEndpointsEnabled ? "Enabled" : "Disabled")
            }
        }
    }

    private var dnsTitle: String {
        switch profile.dns {
        case let .vpnDns(servers): "VPN DNS, \(servers.count) servers"
        case .systemDns: "System DNS"
        case let .customEncrypted(kind, endpoints): "Custom \(kind.rawValue), \(endpoints.count) endpoints"
        }
    }
}
