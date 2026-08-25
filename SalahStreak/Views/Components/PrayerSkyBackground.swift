import SwiftUI

struct PrayerSkyBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            SceneAmbience(scene: scene, reduceMotion: reduceMotion)
                .id(scene)
                .transition(.opacity)

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

private struct SceneAmbience: View {
    let scene: PrayerScene
    let reduceMotion: Bool

    @ViewBuilder
    var body: some View {
        switch scene {
        case .dawn:
            DawnGlowAnimation(reduceMotion: reduceMotion)
        case .daylight:
            DaylightCloudAnimation(reduceMotion: reduceMotion)
        case .goldenHour:
            GoldenMotesAnimation(reduceMotion: reduceMotion)
        case .dusk:
            DuskTwinkleAnimation(reduceMotion: reduceMotion)
        case .night:
            NightSkyAnimation(reduceMotion: reduceMotion)
        }
    }
}

private struct DawnGlowAnimation: View {
    @State private var verticalOffset: CGFloat = 8
    @State private var glowOpacity = 0.0

    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                FirstLight()
                    .offset(
                        x: geometry.size.width * 0.48,
                        y: (geometry.size.height * 0.16) + verticalOffset
                    )
                    .opacity(glowOpacity)
            }
        }
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }

            do {
                try await Task.sleep(for: .seconds(1.0))

                while !Task.isCancelled {
                    resetGlow()

                    withAnimation(.easeOut(duration: 0.45)) {
                        glowOpacity = 0.55
                    }
                    withAnimation(.easeInOut(duration: 2.4)) {
                        verticalOffset = -2
                    }

                    try await Task.sleep(for: .seconds(1.9))

                    withAnimation(.easeOut(duration: 0.35)) {
                        glowOpacity = 0
                    }

                    try await Task.sleep(for: .seconds(6.0))
                }
            } catch {
                // The task is expected to cancel when the scene changes.
            }
        }
    }

    private func resetGlow() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            verticalOffset = 8
            glowOpacity = 0
        }
    }
}

private struct FirstLight: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.5), .orange.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 1,
                        endRadius: 13
                    )
                )
                .frame(width: 28, height: 28)

            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 3.5, height: 3.5)
        }
    }
}

private struct DaylightCloudAnimation: View {
    @State private var progress: CGFloat = 0
    @State private var cloudOpacity = 0.0

    let reduceMotion: Bool

    private let driftDuration = 5.5

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                SoftCloud()
                    .offset(
                        x: geometry.size.width * (0.10 + (0.38 * progress)),
                        y: geometry.size.height * 0.16
                    )
                    .opacity(cloudOpacity)
            }
        }
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }

            do {
                try await Task.sleep(for: .seconds(0.9))

                while !Task.isCancelled {
                    resetCloud()

                    withAnimation(.linear(duration: driftDuration)) {
                        progress = 1
                    }
                    withAnimation(.easeOut(duration: 0.4)) {
                        cloudOpacity = 0.18
                    }

                    try await Task.sleep(for: .seconds(driftDuration - 0.5))

                    withAnimation(.easeOut(duration: 0.4)) {
                        cloudOpacity = 0
                    }

                    try await Task.sleep(for: .seconds(7.0))
                }
            } catch {
                // The task is expected to cancel when the scene changes.
            }
        }
    }

    private func resetCloud() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = 0
            cloudOpacity = 0
        }
    }
}

private struct SoftCloud: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .frame(width: 46, height: 9)

            HStack(alignment: .bottom, spacing: -4) {
                Circle()
                    .frame(width: 14, height: 14)
                Circle()
                    .frame(width: 20, height: 20)
                Circle()
                    .frame(width: 12, height: 12)
            }
            .padding(.bottom, 3)
        }
        .foregroundStyle(.white)
        .blur(radius: 0.35)
    }
}

private struct GoldenMotesAnimation: View {
    @State private var progress: CGFloat = 0
    @State private var moteOpacity = 0.0

    let reduceMotion: Bool

    private let motes = [
        GoldenMote(x: 0.56, y: 0.16, size: 3.0, rise: 11),
        GoldenMote(x: 0.66, y: 0.22, size: 2.2, rise: 16),
        GoldenMote(x: 0.74, y: 0.14, size: 2.6, rise: 13)
    ]

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                ForEach(motes) { mote in
                    Circle()
                        .fill(Color(red: 1.0, green: 0.84, blue: 0.58))
                        .frame(width: mote.size, height: mote.size)
                        .shadow(color: .orange.opacity(0.45), radius: 3)
                        .offset(
                            x: geometry.size.width * mote.x,
                            y: (geometry.size.height * mote.y) - (mote.rise * progress)
                        )
                        .scaleEffect(0.92 + (0.12 * progress))
                        .opacity(moteOpacity)
                }
            }
        }
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }

            do {
                try await Task.sleep(for: .seconds(1.1))

                while !Task.isCancelled {
                    resetMotes()

                    withAnimation(.easeInOut(duration: 2.0)) {
                        progress = 1
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        moteOpacity = 0.58
                    }

                    try await Task.sleep(for: .seconds(1.55))

                    withAnimation(.easeOut(duration: 0.35)) {
                        moteOpacity = 0
                    }

                    try await Task.sleep(for: .seconds(5.5))
                }
            } catch {
                // The task is expected to cancel when the scene changes.
            }
        }
    }

    private func resetMotes() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = 0
            moteOpacity = 0
        }
    }
}

private struct GoldenMote: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let rise: CGFloat
}

private struct DuskTwinkleAnimation: View {
    @State private var starScale: CGFloat = 0.92
    @State private var starOpacity = 0.0

    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                FirstStar()
                    .scaleEffect(starScale)
                    .offset(
                        x: geometry.size.width * 0.58,
                        y: geometry.size.height * 0.17
                    )
                    .opacity(starOpacity)
            }
        }
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }

            do {
                try await Task.sleep(for: .seconds(1.0))

                while !Task.isCancelled {
                    resetTwinkle()

                    withAnimation(.easeOut(duration: 0.3)) {
                        starScale = 1
                        starOpacity = 0.72
                    }

                    try await Task.sleep(for: .seconds(0.6))

                    withAnimation(.easeOut(duration: 0.35)) {
                        starScale = 0.94
                        starOpacity = 0
                    }

                    try await Task.sleep(for: .seconds(4.4))
                }
            } catch {
                // The task is expected to cancel when the scene changes.
            }
        }
    }

    private func resetTwinkle() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            starScale = 0.92
            starOpacity = 0
        }
    }
}

private struct FirstStar: View {
    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 1, height: 10)
            Capsule()
                .frame(width: 10, height: 1)
            Circle()
                .frame(width: 2.5, height: 2.5)
        }
        .foregroundStyle(.white)
        .shadow(color: .white.opacity(0.7), radius: 3)
    }
}

private struct NightSkyAnimation: View {
    @State private var progress: CGFloat = 0
    @State private var starOpacity = 0.0

    let reduceMotion: Bool

    private let flightDuration = 1.15
    private let restDuration = 7.35

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                ShootingStar()
                    .rotationEffect(.degrees(27))
                    .offset(
                        x: geometry.size.width * (0.24 + (0.43 * progress)),
                        y: geometry.size.height * (0.15 + (0.16 * progress))
                    )
                    .opacity(starOpacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }

            do {
                try await Task.sleep(for: .seconds(1.2))

                while !Task.isCancelled {
                    resetStar()

                    withAnimation(.linear(duration: flightDuration)) {
                        progress = 1
                    }
                    withAnimation(.easeOut(duration: 0.16)) {
                        starOpacity = 0.78
                    }

                    try await Task.sleep(for: .seconds(flightDuration * 0.72))

                    withAnimation(.easeOut(duration: flightDuration * 0.28)) {
                        starOpacity = 0
                    }

                    try await Task.sleep(for: .seconds((flightDuration * 0.28) + restDuration))
                }
            } catch {
                // The task is expected to cancel when night ends or the view disappears.
            }
        }
    }

    private func resetStar() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = 0
            starOpacity = 0
        }
    }
}

private struct ShootingStar: View {
    var body: some View {
        HStack(spacing: -1) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .white.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 44, height: 1.4)

            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .shadow(color: .white.opacity(0.8), radius: 3)
        }
    }
}
