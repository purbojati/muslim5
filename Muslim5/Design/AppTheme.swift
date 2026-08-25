import SwiftUI

enum AppTheme {
    static let accent = Color("AccentColor")
    static let ink = Color(red: 0.03, green: 0.24, blue: 0.22)
    static let parchment = Color(red: 0.97, green: 0.93, blue: 0.80)
    static let warmOrange = Color(red: 0.96, green: 0.43, blue: 0.18)
    static let success = Color(red: 0.16, green: 0.55, blue: 0.45)
    static let gold = Color(red: 0.94, green: 0.64, blue: 0.29)

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
