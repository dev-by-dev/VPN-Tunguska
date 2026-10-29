import SwiftUI
import TunguskaCore

struct RoutingView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
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
                    PanelCard(title: settings.t(L10n.Key.sidebarRouting), systemImage: "arrow.triangle.branch") {
                        Text(settings.t(L10n.Key.routingEmpty))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(settings.t(L10n.Key.sidebarRouting))
    }

    private func regionalBypassPanel(_ profile: ProfileIr) -> some View {
        PanelCard(title: settings.t(L10n.Key.homeRegionalBypass), systemImage: "map") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(settings.t(L10n.Key.routingRussiaToggle), isOn: Binding(
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

                Text(settings.t(L10n.Key.routingGeoipHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.t(L10n.Key.routingCustomDirectDomains))
                        .font(.headline)
                    Text(settings.t(L10n.Key.routingCustomDirectDomainsHint))
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
        PanelCard(title: settings.t(L10n.Key.routingRoutePreview), systemImage: "binoculars") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    TextField(settings.t(L10n.Key.routingFieldAppBundleID), text: $previewForm.packageName)
                    TextField(settings.t(L10n.Key.routingFieldDestinationHost), text: $previewForm.destinationHost)
                    TextField(settings.t(L10n.Key.routingFieldDestinationIp), text: $previewForm.destinationIp)
                    TextField(settings.t(L10n.Key.commonPort), text: $previewForm.destinationPort)
                        .frame(width: 90)
                    Picker(settings.t(L10n.Key.commonProtocol), selection: $previewForm.protocolName) {
                        Text(settings.t(L10n.Key.commonAny)).tag("")
                        Text(NetworkProtocol.tcp.rawValue).tag(NetworkProtocol.tcp.rawValue)
                        Text(NetworkProtocol.udp.rawValue).tag(NetworkProtocol.udp.rawValue)
                    }
                    .frame(width: 130)
                }

                HStack {
                    Button(settings.t(L10n.Key.routingEvaluate)) {
                        previewOutcome = model.evaluateRoutePreview(previewForm)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(settings.t(L10n.Key.commonReset)) {
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
                    Text(settings.t(L10n.Key.routingOfflineHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func effectiveRulesPanel(_ profile: ProfileIr) -> some View {
        PanelCard(title: settings.t(L10n.Key.routingResolvedPolicy), systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                if let policy = try? EffectiveRoutingPolicyResolver.resolve(profile) {
                    LabeledContent(settings.t(L10n.Key.routingBlockRulesFirst), value: "\(profile.routing.rules.filter { $0.action == .block }.count)")
                    LabeledContent(settings.t(L10n.Key.routingGeneratedRegionalRules), value: "\(policy.generatedRegionalRuleCount)")
                    LabeledContent(settings.t(L10n.Key.routingNonBlockRules), value: "\(profile.routing.rules.filter { $0.action != .block }.count)")
                    LabeledContent(
                        settings.t(L10n.Key.routingCustomDirectDomains),
                        value: policy.normalizedCustomDirectDomains.isEmpty
                            ? settings.t(L10n.Key.commonNone)
                            : policy.normalizedCustomDirectDomains.joined(separator: ", ")
                    )
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
                    InlineMessage(text: settings.t(L10n.Key.routingInvalidPolicy), tone: .error)
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
        if !match.domainExact.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaExact)) \(match.domainExact.count)") }
        if !match.domainSuffix.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaSuffix)) \(match.domainSuffix.count)") }
        if !match.domainKeyword.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaKeyword)) \(match.domainKeyword.count)") }
        if !match.ipCidrs.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaCidr)) \(match.ipCidrs.count)") }
        if !match.geoSites.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaGeosite)) \(match.geoSites.count)") }
        if !match.geoIps.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaGeoip)) \(match.geoIps.count)") }
        if !match.asns.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaAsn)) \(match.asns.count)") }
        if !match.packageNames.isEmpty { parts.append("\(settings.t(L10n.Key.routingCriteriaApp)) \(match.packageNames.count)") }
        if !match.ports.isEmpty { parts.append("\(settings.t(L10n.Key.commonPort)) \(match.ports.count)") }
        if !match.protocols.isEmpty { parts.append(match.protocols.map { $0.rawValue }.joined(separator: "/")) }
        return parts.isEmpty ? settings.t(L10n.Key.routingNoCriteria) : parts.joined(separator: " · ")
    }
}
