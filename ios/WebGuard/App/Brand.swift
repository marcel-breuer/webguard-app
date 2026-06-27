import SwiftUI

enum Brand {
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let surface = Color.white
    static let text = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let mutedText = Color(red: 0.28, green: 0.34, blue: 0.43)
    static let border = Color(red: 0.89, green: 0.92, blue: 0.95)
    static let accent = Color(red: 0.55, green: 0.17, blue: 0.96)
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

extension View {
    func webGuardCard() -> some View {
        modifier(CardModifier())
    }

    func webGuardContentWidth(_ maxWidth: CGFloat = 860) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
