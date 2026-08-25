import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.45, green: 0.38, blue: 0.88)
    static let deepIndigo = Color(red: 0.17, green: 0.12, blue: 0.25)
    static let success = Color(red: 0.25, green: 0.67, blue: 0.50)
    static let gold = Color(red: 0.94, green: 0.65, blue: 0.28)

    static func prayerColor(for prayer: Prayer) -> Color {
        switch prayer {
        case .fajr:
            Color(red: 0.93, green: 0.47, blue: 0.27)
        case .dhuhr:
            Color(red: 0.83, green: 0.55, blue: 0.10)
        case .asr:
            Color(red: 0.35, green: 0.52, blue: 0.86)
        case .maghrib:
            Color(red: 0.82, green: 0.34, blue: 0.47)
        case .isha:
            Color(red: 0.48, green: 0.37, blue: 0.84)
        }
    }

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
