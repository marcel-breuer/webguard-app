import SwiftUI

enum Brand {
    static let background = Color(red: 0.965, green: 0.973, blue: 0.984)
    static let surface = Color.white
    static let text = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let mutedText = Color(red: 0.34, green: 0.38, blue: 0.46)
    static let border = Color(red: 0.87, green: 0.89, blue: 0.93)
    static let accent = Color(red: 0.49, green: 0.14, blue: 0.77)
    static let accentDeep = Color(red: 0.23, green: 0.02, blue: 0.39)
    static let accentSoft = Color(red: 0.96, green: 0.93, blue: 1.0)
    static let success = Color(red: 0.18, green: 0.62, blue: 0.33)
    static let successMuted = Color(red: 0.92, green: 0.98, blue: 0.94)
    static let danger = Color(red: 0.94, green: 0.27, blue: 0.27)
    static let dangerMuted = Color(red: 1.0, green: 0.93, blue: 0.93)
    static let warning = Color(red: 0.85, green: 0.60, blue: 0.0)
    static let warningMuted = Color(red: 1.0, green: 0.97, blue: 0.84)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Brand.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Brand.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct WebGuardStatusBadge: View {
    let tone: MonitorTone
    let label: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tone.color)
                .frame(width: 7, height: 7)
            Text(label ?? tone.displayName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tone.background)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? tone.displayName)
    }
}

extension MonitorTone {
    var color: Color {
        switch self {
        case .up: return Brand.success
        case .down: return Brand.danger
        case .maintenance: return Brand.warning
        case .unknown: return Brand.mutedText
        }
    }

    var background: Color {
        switch self {
        case .up: return Brand.successMuted
        case .down: return Brand.dangerMuted
        case .maintenance: return Brand.warningMuted
        case .unknown: return Brand.border
        }
    }

    var displayName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .maintenance: return "Maintenance"
        case .unknown: return "Unknown"
        }
    }
}

extension View {
    func webGuardCard() -> some View {
        modifier(CardModifier())
    }

    func webGuardContentWidth(_ maxWidth: CGFloat = 860) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
