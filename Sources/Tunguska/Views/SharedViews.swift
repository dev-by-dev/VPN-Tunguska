import SwiftUI
import TunguskaCore

struct StatusPill: View {
    let state: TunnelObservedState

    var body: some View {
        Label(state.title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var iconName: String {
        switch state {
        case .connected: "checkmark.circle.fill"
        case .connecting, .disconnecting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .failed: "exclamationmark.triangle.fill"
        case .disconnected: "circle.dotted"
        case .unavailable: "lock.open"
        }
    }

    private var color: Color {
        switch state {
        case .connected: .green
        case .connecting, .disconnecting: .orange
        case .failed: .red
        case .disconnected: .secondary
        case .unavailable: .gray
        }
    }
}

struct PanelCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct InlineMessage: View {
    let text: String
    var tone: Tone = .secondary

    enum Tone {
        case secondary
        case warning
        case error

        var color: Color {
            switch self {
            case .secondary: .secondary
            case .warning: .orange
            case .error: .red
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(tone.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ActionBadge: View {
    let action: RouteAction

    var body: some View {
        Text(action.rawValue)
            .font(.caption.weight(.bold).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var color: Color {
        switch action {
        case .proxy: .blue
        case .direct: .green
        case .block: .red
        }
    }
}

func maskedSecret(_ value: String, visiblePrefix: Int = 6, visibleSuffix: Int = 4) -> String {
    guard value.count > visiblePrefix + visibleSuffix else {
        return String(repeating: "•", count: value.count)
    }
    return "\(value.prefix(visiblePrefix))…\(value.suffix(visibleSuffix))"
}

/// Quiet, full-width menu-row buttons for the menu bar panel: flat by
/// default, with a subtle rounded highlight on hover and a slightly
/// stronger one while pressed.
struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(highlightOpacity(isPressed: configuration.isPressed)))
            )
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }

    private func highlightOpacity(isPressed: Bool) -> Double {
        guard isEnabled else { return 0 }
        if isPressed { return 0.14 }
        return isHovering ? 0.08 : 0
    }
}
