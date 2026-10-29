import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PanelCard(title: settings.t(L10n.Key.settingsLanguage), systemImage: "globe") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(settings.t(L10n.Key.settingsLanguage), selection: $settings.appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.nativeLabel).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()

                        Text(settings.t(L10n.Key.settingsLanguageHint))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(settings.t(L10n.Key.sidebarSettings))
    }
}
