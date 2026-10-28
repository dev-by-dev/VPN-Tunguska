import AppKit
import SwiftUI
import TunguskaCore
import UniformTypeIdentifiers

struct SecurityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var backupPassphrase = ""
    @State private var backupMessage: String?
    @State private var backupError: String?
    @State private var diagnosticsText = ""
    @State private var diagnosticsError: String?

    private static let backupType = UTType(filenameExtension: "tunguska") ?? .data

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: "Local storage", systemImage: "key.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Profile count", value: "\(model.profiles.count)")
                        LabeledContent("Active profile", value: model.activeProfile?.name ?? "None")
                        LabeledContent("Storage", value: "macOS Keychain, this-device accessible")
                        LabeledContent("Auto-connect after import", value: "Disabled")
                        if let storageError = model.storageError {
                            InlineMessage(text: storageError, tone: .error)
                        }
                    }
                }

                PanelCard(title: "Encrypted backup", systemImage: "lock.doc") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exports every profile into one authenticated AES-256-GCM container. The passphrase derives the key with PBKDF2-HMAC-SHA256 and is never stored.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        SecureField("Backup passphrase (12 characters or more)", text: $backupPassphrase)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            Button("Export backup", systemImage: "square.and.arrow.up") {
                                exportBackup()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.profiles.isEmpty)

                            Button("Restore backup", systemImage: "square.and.arrow.down") {
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

                PanelCard(title: "Redacted diagnostics", systemImage: "text.viewfinder") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Builds a support report without profile IDs, names, endpoints, UUIDs, REALITY keys, DNS addresses, rule domains, or share links.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Button("Generate report", systemImage: "doc.text.magnifyingglass") {
                                generateDiagnostics()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Copy", systemImage: "doc.on.doc") {
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

                PanelCard(title: "Safety posture", systemImage: "checkmark.shield") {
                    VStack(alignment: .leading, spacing: 10) {
                        SafetyRow(title: "Safe mode", detail: "Unsafe imported profiles are rejected.", enabled: model.activeProfile?.safety.safeMode ?? false)
                        SafetyRow(title: "Compatibility local proxy", detail: "Kept disabled for the local build.", enabled: model.activeProfile?.safety.compatibilityLocalProxy ?? false, invert: true)
                        SafetyRow(title: "Debug endpoints", detail: "Kept disabled for the local build.", enabled: model.activeProfile?.safety.debugEndpointsEnabled ?? false, invert: true)
                        SafetyRow(title: "Fail-closed tunnel policy", detail: "An invalid runtime configuration must not connect.", enabled: true)
                    }
                }

                PanelCard(title: "Connection invariants", systemImage: "network.badge.shield.half.filled") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Only a live TUN interface from the privileged helper can produce the Connected state.", systemImage: "checkmark.circle")
                        Label("Desired state is separate from observed runtime state.", systemImage: "checkmark.circle")
                        Label("Secrets are masked in the UI and are not written to logs.", systemImage: "checkmark.circle")
                        Label("Loopback destinations remain direct by routing policy.", systemImage: "checkmark.circle")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                PanelCard(title: "Runtime packaging", systemImage: "shippingbox") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("App target", value: "SwiftUI instrument panel")
                        LabeledContent("Tunnel target", value: "Privileged helper + sing-box CLI")
                        LabeledContent("Engine", value: "Pinned sing-box CLI, arm64")
                        Text("The helper installs a LaunchDaemon under /Library/Tunguska and requires an administrator password once during setup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("This Clash-Verge-style path avoids the NetworkExtension entitlement. Gatekeeper may warn for unsigned local builds; do not run an unsigned privileged helper from untrusted sources.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("Security")
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
            backupMessage = "Encrypted backup written to \(url.lastPathComponent)."
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
            backupMessage = "Restored \(count) profile\(count == 1 ? "" : "s") from \(url.lastPathComponent)."
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
    let title: String
    let detail: String
    let enabled: Bool
    var invert: Bool = false

    private var displayState: (String, Color) {
        let displayed = invert ? !enabled : enabled
        return displayed ? ("Pass", .green) : ("Restricted", .orange)
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
