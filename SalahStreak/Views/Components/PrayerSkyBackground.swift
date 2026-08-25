import SwiftUI

struct PrayerSkyBackground: View {
    let scene: PrayerScene

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("PrayerAtmosphere")
                .resizable()
                .scaledToFill()
                .saturation(0.8)
                .contrast(1.1)
                .blendMode(.overlay)
                .opacity(illustrationOpacity)

            Color.black.opacity(legibilityOverlayOpacity)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: scene)
        .accessibilityHidden(true)
    }

    private var illustrationOpacity: Double {
        switch scene {
        case .daylight: 0.62
        case .dawn, .goldenHour: 0.58
        case .dusk: 0.52
        case .night: 0.46
        }
    }

    private var legibilityOverlayOpacity: Double {
        scene == .daylight ? 0.08 : 0.04
    }

    private var palette: [Color] {
        switch scene {
        case .dawn:
            [
                Color(red: 0.20, green: 0.22, blue: 0.38),
                Color(red: 0.52, green: 0.39, blue: 0.48)
            ]
        case .daylight:
            [
                Color(red: 0.25, green: 0.45, blue: 0.60),
                Color(red: 0.43, green: 0.61, blue: 0.67)
            ]
        case .goldenHour:
            [
                Color(red: 0.34, green: 0.38, blue: 0.50),
                Color(red: 0.65, green: 0.46, blue: 0.38)
            ]
        case .dusk:
            [
                Color(red: 0.23, green: 0.21, blue: 0.36),
                Color(red: 0.48, green: 0.33, blue: 0.41)
            ]
        case .night:
            [
                Color(red: 0.08, green: 0.10, blue: 0.18),
                Color(red: 0.18, green: 0.18, blue: 0.29)
            ]
        }
    }
}
