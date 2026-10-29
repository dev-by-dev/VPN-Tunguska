import SwiftUI
import TunguskaCore

struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

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
                        PanelCard(title: settings.t(L10n.Key.commonProfile), systemImage: "rectangle.on.rectangle") {
                            Text(settings.t(L10n.Key.profilesSelectOrImport))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 820, alignment: .leading)
            }
        }
        .navigationTitle(settings.t(L10n.Key.sidebarProfiles))
    }

    private var profileList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t(L10n.Key.sidebarProfiles))
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
                            Label(settings.t(L10n.Key.profilesActive), systemImage: "checkmark.seal.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.green)
                        } else {
                            Button(settings.t(L10n.Key.commonSelect)) {
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
                        Button(settings.t(L10n.Key.commonDelete), role: .destructive) {
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
        PanelCard(title: settings.t(L10n.Key.profilesStagedImport), systemImage: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $model.importText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                HStack {
                    Button(settings.t(L10n.Key.profilesValidateImport)) {
                        model.stageImport()
                    }
                    .disabled(model.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(settings.t(L10n.Key.commonDiscard), role: .cancel) {
                        model.discardImport()
                        model.importText = ""
                    }
                    .disabled(model.importPreview == nil && model.importError == nil)

                    Spacer()

                    Text(settings.t(L10n.Key.profilesImportNeverAutoConnects))
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
                        LabeledContent(settings.t(L10n.Key.commonName), value: preview.profile.name)
                        LabeledContent(settings.t(L10n.Key.commonEndpoint), value: preview.profile.endpointSummary)
                        LabeledContent(settings.t(L10n.Key.commonFlow), value: preview.profile.outbound.flow ?? settings.t(L10n.Key.commonDefault))
                        LabeledContent(settings.t(L10n.Key.commonSNI), value: preview.profile.outbound.serverName)

                        ForEach(preview.warnings, id: \.self) { warning in
                            InlineMessage(text: warning, tone: .warning)
                        }

                        HStack {
                            Button(settings.t(L10n.Key.profilesSaveToKeychain)) {
                                model.confirmImport()
                            }
                            .buttonStyle(.borderedProminent)
                            Button(settings.t(L10n.Key.profilesDiscardPreview), role: .cancel) {
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
    @EnvironmentObject private var settings: AppSettings
    let profile: ProfileIr

    var body: some View {
        PanelCard(title: settings.t(L10n.Key.profilesActiveProfile), systemImage: "rectangle.on.rectangle") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent(settings.t(L10n.Key.commonName), value: profile.name)
                LabeledContent(settings.t(L10n.Key.commonEndpoint), value: profile.endpointSummary)
                LabeledContent(settings.t(L10n.Key.commonFlow), value: profile.outbound.flow ?? settings.t(L10n.Key.commonDefault))
                LabeledContent("uTLS", value: profile.outbound.utlsFingerprint)
                LabeledContent("Spider X", value: profile.outbound.effectiveRealitySpiderX)
                LabeledContent(settings.t(L10n.Key.commonSNI), value: profile.outbound.serverName)

                Divider()

                LabeledContent("UUID", value: maskedSecret(profile.outbound.uuid))
                LabeledContent(settings.t(L10n.Key.profilesRealityPublicKey), value: maskedSecret(profile.outbound.realityPublicKey))
                LabeledContent(settings.t(L10n.Key.profilesRealityShortId), value: maskedSecret(profile.outbound.realityShortId))

                Divider()

                LabeledContent(settings.t(L10n.Key.homeDnsLabel), value: dnsTitle)
                LabeledContent(settings.t(L10n.Key.commonSafeMode), value: profile.safety.safeMode ? settings.t(L10n.Key.commonOn) : settings.t(L10n.Key.commonOff))
                LabeledContent(settings.t(L10n.Key.commonLocalProxy), value: profile.safety.compatibilityLocalProxy ? settings.t(L10n.Key.commonEnabled) : settings.t(L10n.Key.commonDisabled))
                LabeledContent(settings.t(L10n.Key.commonDebugEndpoints), value: profile.safety.debugEndpointsEnabled ? settings.t(L10n.Key.commonEnabled) : settings.t(L10n.Key.commonDisabled))
            }
        }
    }

    private var dnsTitle: String {
        switch profile.dns {
        case let .vpnDns(servers): settings.fmt(L10n.Key.profilesDnsVpnServersFormat, servers.count)
        case .systemDns: settings.t(L10n.Key.commonSystemDns)
        case let .customEncrypted(kind, endpoints): settings.fmt(L10n.Key.profilesDnsCustomFormat, kind.rawValue, endpoints.count)
        }
    }
}
