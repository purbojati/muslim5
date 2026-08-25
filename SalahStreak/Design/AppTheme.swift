import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.45, green: 0.38, blue: 0.88)
    static let deepIndigo = Color(red: 0.17, green: 0.12, blue: 0.25)
    static let warmBackground = Color(red: 0.97, green: 0.95, blue: 0.92)
    static let success = Color(red: 0.25, green: 0.67, blue: 0.50)
    static let gold = Color(red: 0.94, green: 0.65, blue: 0.28)

    static let cardGradient = LinearGradient(
        colors: [deepIndigo, Color(red: 0.34, green: 0.27, blue: 0.50)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func contributionColor(for count: Int) -> Color {
        switch count {
        case 1: accent.opacity(0.24)
        case 2: accent.opacity(0.42)
        case 3: accent.opacity(0.62)
        case 4: accent.opacity(0.82)
        case 5...: success
        default: Color.secondary.opacity(0.11)
        }
    }
}
