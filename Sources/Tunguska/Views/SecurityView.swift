import AppKit
import SwiftUI
import TunguskaCore
import UniformTypeIdentifiers

struct SecurityView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var backupPassphrase = ""
    @State private var backupMessage: String?
    @State private var backupError: String?
    @State private var diagnosticsText = ""
    @State private var diagnosticsError: String?

    private static let backupType = UTType(filenameExtension: "tunguska") ?? .data

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: settings.t(L10n.Key.securityLocalStorage), systemImage: "key.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent(settings.t(L10n.Key.securityProfileCount), value: "\(model.profiles.count)")
                        LabeledContent(settings.t(L10n.Key.profilesActiveProfile), value: model.activeProfile?.name ?? settings.t(L10n.Key.commonNone))
                        LabeledContent(settings.t(L10n.Key.securityStorageLabel), value: settings.t(L10n.Key.securityStorageValue))
                        LabeledContent(settings.t(L10n.Key.securityAutoConnectAfterImport), value: settings.t(L10n.Key.commonDisabled))
                        if let storageError = model.storageError {
                            InlineMessage(text: storageError, tone: .error)
                        }
                    }
                }

                PanelCard(title: settings.t(L10n.Key.securityEncryptedBackup), systemImage: "lock.doc") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(settings.t(L10n.Key.securityBackupDescription))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        SecureField(settings.t(L10n.Key.securityBackupPassphrase), text: $backupPassphrase)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            Button(settings.t(L10n.Key.securityExportBackup), systemImage: "square.and.arrow.up") {
                                exportBackup()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.profiles.isEmpty)

                            Button(settings.t(L10n.Key.securityRestoreBackup), systemImage: "square.and.arrow.down") {
                                restoreBackup()
                            }
                            .buttonStyle(.bordered)
                        }
                        if let backupMessage {
                            InlineMessage(text: backupMessage)
                        }
                        if let backupError {
                            InlineMessage(text: backupError, tone: .error)
                        }
                    }
                }

                PanelCard(title: settings.t(L10n.Key.securityRedactedDiagnostics), systemImage: "text.viewfinder") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(settings.t(L10n.Key.securityDiagnosticsDescription))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Button(settings.t(L10n.Key.securityGenerateReport), systemImage: "doc.text.magnifyingglass") {
                                generateDiagnostics()
                            }
                            .buttonStyle(.borderedProminent)

                            Button(settings.t(L10n.Key.commonCopy), systemImage: "doc.on.doc") {
                                copyDiagnostics()
                            }
                            .buttonStyle(.bordered)
                            .disabled(diagnosticsText.isEmpty)
                        }
                        TextEditor(text: $diagnosticsText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 120)
                            .padding(6)
                            .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                        if let diagnosticsError {
                            InlineMessage(text: diagnosticsError, tone: .error)
                        }
                    }
                }

                PanelCard(title: settings.t(L10n.Key.securitySafetyPosture), systemImage: "checkmark.shield") {
                    VStack(alignment: .leading, spacing: 10) {
                        SafetyRow(title: settings.t(L10n.Key.commonSafeMode), detail: settings.t(L10n.Key.securitySafeModeDetail), enabled: model.activeProfile?.safety.safeMode ?? false)
                        SafetyRow(title: settings.t(L10n.Key.commonLocalProxy), detail: settings.t(L10n.Key.securityKeptDisabled), enabled: model.activeProfile?.safety.compatibilityLocalProxy ?? false, invert: true)
                        SafetyRow(title: settings.t(L10n.Key.commonDebugEndpoints), detail: settings.t(L10n.Key.securityKeptDisabled), enabled: model.activeProfile?.safety.debugEndpointsEnabled ?? false, invert: true)
                        SafetyRow(title: settings.t(L10n.Key.securityFailClosed), detail: settings.t(L10n.Key.securityFailClosedDetail), enabled: true)
                    }
                }

                PanelCard(title: settings.t(L10n.Key.securityConnectionInvariants), systemImage: "network.badge.shield.half.filled") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(settings.t(L10n.Key.securityInvariantConnected), systemImage: "checkmark.circle")
                        Label(settings.t(L10n.Key.securityInvariantDesired), systemImage: "checkmark.circle")
                        Label(settings.t(L10n.Key.securityInvariantSecrets), systemImage: "checkmark.circle")
                        Label(settings.t(L10n.Key.securityInvariantLoopback), systemImage: "checkmark.circle")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                PanelCard(title: settings.t(L10n.Key.securityRuntimePackaging), systemImage: "shippingbox") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent(settings.t(L10n.Key.securityAppTarget), value: settings.t(L10n.Key.securityAppTargetValue))
                        LabeledContent(settings.t(L10n.Key.securityTunnelTarget), value: settings.t(L10n.Key.securityTunnelTargetValue))
                        LabeledContent(settings.t(L10n.Key.securityEngine), value: settings.t(L10n.Key.securityEngineValue))
                        Text(settings.t(L10n.Key.securityHelperInstallNote))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settings.t(L10n.Key.securityGatekeeperNote))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle(settings.t(L10n.Key.sidebarSecurity))
    }

    private func exportBackup() {
        backupMessage = nil
        backupError = nil
        do {
            let data = try model.exportBackup(passphrase: backupPassphrase)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [Self.backupType]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "Tunguska-\(Int(Date().timeIntervalSince1970)).tunguska"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            backupMessage = settings.fmt(L10n.Key.securityBackupWrittenFormat, url.lastPathComponent)
        } catch {
            backupError = error.localizedDescription
        }
    }

    private func restoreBackup() {
        backupMessage = nil
        backupError = nil
        do {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [Self.backupType]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let data = try Data(contentsOf: url)
            guard data.count <= 10 * 1024 * 1024 else {
                throw ProfileBackupError.malformedEnvelope
            }
            let count = try model.importBackup(data: data, passphrase: backupPassphrase)
            backupMessage = count == 1
                ? settings.fmt(L10n.Key.securityRestoredOneFormat, url.lastPathComponent)
                : settings.fmt(L10n.Key.securityRestoredManyFormat, count, url.lastPathComponent)
        } catch {
            backupError = error.localizedDescription
        }
    }

    private func generateDiagnostics() {
        diagnosticsError = nil
        do {
            diagnosticsText = try model.diagnosticsReport()
        } catch {
            diagnosticsText = ""
            diagnosticsError = error.localizedDescription
        }
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticsText, forType: .string)
    }
}

private struct SafetyRow: View {
    @EnvironmentObject private var settings: AppSettings
    let title: String
    let detail: String
    let enabled: Bool
    var invert: Bool = false

    private var displayState: (String, Color) {
        let displayed = invert ? !enabled : enabled
        return displayed ? (settings.t(L10n.Key.securityPass), .green) : (settings.t(L10n.Key.securityRestricted), .orange)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: displayState.1 == .green ? "checkmark.seal.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(displayState.1)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(displayState.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(displayState.1)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
