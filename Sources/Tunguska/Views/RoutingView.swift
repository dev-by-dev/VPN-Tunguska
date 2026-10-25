import SwiftUI
import TunguskaCore

struct RoutingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var previewForm = RoutePreviewForm()
    @State private var previewOutcome: RoutePreviewEvaluation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let profile = model.activeProfile {
                    regionalBypassPanel(profile)
                    routePreviewPanel(profile)
                    effectiveRulesPanel(profile)
                } else {
                    PanelCard(title: "Routing", systemImage: "arrow.triangle.branch") {
                        Text("Select a profile to inspect and preview routing.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("Routing")
    }

    private func regionalBypassPanel(_ profile: ProfileIr) -> some View {
        PanelCard(title: "Regional bypass", systemImage: "map") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Route Russian domains (.ru, .su, .xn--p1ai) directly", isOn: Binding(
                    get: { profile.routing.regionalBypass.isPresetEnabled(.russia) },
                    set: { enabled in
                        model.updateActiveProfile { current in
                            var presets = current.routing.regionalBypass.enabledPresets
                            if enabled {
                                if !presets.contains(.russia) { presets.append(.russia) }
                            } else {
                                presets.removeAll { $0 == .russia }
                            }
                            current.routing.regionalBypass.enabledPresets = presets
                        }
                    }
                ))

                Text("GeoIP:RU is shown as a runtime hint until a regional dataset is bundled; the local configuration applies domain suffixes only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom direct domains")
                        .font(.headline)
                    Text("One domain per line. Unicode domains are normalized to IDN.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: customDomainsBinding(for: profile))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                }

                if let message = model.profileValidationMessage {
                    InlineMessage(text: message, tone: .error)
                }
            }
        }
    }

    private func routePreviewPanel(_ profile: ProfileIr) -> some View {
        PanelCard(title: "Route preview", systemImage: "binoculars") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    TextField("App bundle ID", text: $previewForm.packageName)
                    TextField("Destination host", text: $previewForm.destinationHost)
                    TextField("Destination IP", text: $previewForm.destinationIp)
                    TextField("Port", text: $previewForm.destinationPort)
                        .frame(width: 90)
                    Picker("Protocol", selection: $previewForm.protocolName) {
                        Text("Any").tag("")
                        Text("TCP").tag(NetworkProtocol.tcp.rawValue)
                        Text("UDP").tag(NetworkProtocol.udp.rawValue)
                    }
                    .frame(width: 130)
                }

                HStack {
                    Button("Evaluate") {
                        previewOutcome = model.evaluateRoutePreview(previewForm)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reset") {
                        previewForm = RoutePreviewForm()
                        previewOutcome = nil
                    }
                    Spacer()
                }

                if let previewOutcome {
                    switch previewOutcome {
                    case let .success(outcome):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                ActionBadge(action: outcome.action)
                                if let matchedRuleID = outcome.matchedRuleId {
                                    Text(matchedRuleID)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(outcome.reason)
                            if let hint = outcome.runtimeDatasetHint {
                                InlineMessage(text: hint, tone: .warning)
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case let .failure(message):
                        InlineMessage(text: message, tone: .error)
                    }
                } else {
                    Text("Evaluation is offline; GeoSite/GeoIP/ASN-only matches are reported as runtime hints rather than silently claimed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func effectiveRulesPanel(_ profile: ProfileIr) -> some View {
        PanelCard(title: "Resolved policy", systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                if let policy = try? EffectiveRoutingPolicyResolver.resolve(profile) {
                    LabeledContent("Block rules first", value: "\(profile.routing.rules.filter { $0.action == .block }.count)")
                    LabeledContent("Generated regional rules", value: "\(policy.generatedRegionalRuleCount)")
                    LabeledContent("Non-block rules", value: "\(profile.routing.rules.filter { $0.action != .block }.count)")
                    LabeledContent("Custom direct domains", value: policy.normalizedCustomDirectDomains.isEmpty ? "None" : policy.normalizedCustomDirectDomains.joined(separator: ", "))
                    Divider()
                    ForEach(Array(policy.rules.enumerated()), id: \.element.id) { _, rule in
                        HStack {
                            ActionBadge(action: rule.action)
                            Text(rule.id)
                                .font(.caption.monospaced())
                            Spacer()
                            Text(criteriaSummary(rule.match))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    InlineMessage(text: "The routing policy contains an invalid regional bypass domain.", tone: .error)
                }
            }
        }
    }

    private func customDomainsBinding(for profile: ProfileIr) -> Binding<String> {
        Binding(
            get: { profile.routing.regionalBypass.customDirectDomains.joined(separator: "\n") },
            set: { newValue in
                model.updateActiveProfile { current in
                    current.routing.regionalBypass.customDirectDomains = newValue
                        .split(separator: "\n", omittingEmptySubsequences: true)
                        .map(String.init)
                }
            }
        )
    }

    private func criteriaSummary(_ match: RouteMatch) -> String {
        var parts: [String] = []
        if !match.domainExact.isEmpty { parts.append("exact \(match.domainExact.count)") }
        if !match.domainSuffix.isEmpty { parts.append("suffix \(match.domainSuffix.count)") }
        if !match.domainKeyword.isEmpty { parts.append("keyword \(match.domainKeyword.count)") }
        if !match.ipCidrs.isEmpty { parts.append("cidr \(match.ipCidrs.count)") }
        if !match.geoSites.isEmpty { parts.append("geosite \(match.geoSites.count)") }
        if !match.geoIps.isEmpty { parts.append("geoip \(match.geoIps.count)") }
        if !match.asns.isEmpty { parts.append("asn \(match.asns.count)") }
        if !match.packageNames.isEmpty { parts.append("app \(match.packageNames.count)") }
        if !match.ports.isEmpty { parts.append("port \(match.ports.count)") }
        if !match.protocols.isEmpty { parts.append(match.protocols.map { $0.rawValue }.joined(separator: "/")) }
        return parts.isEmpty ? "No criteria" : parts.joined(separator: " · ")
    }
}
