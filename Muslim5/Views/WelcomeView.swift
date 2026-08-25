import SwiftUI

struct AppLaunchView: View {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if hasCompletedWelcome {
                RootTabView()
                    .transition(.opacity)
            } else {
                WelcomeView {
                    HapticFeedback.impact(.medium, intensity: 0.8)

                    withAnimation(
                        reduceMotion
                            ? .linear(duration: 0.10)
                            : .timingCurve(0.23, 1, 0.32, 1, duration: 0.26)
                    ) {
                        hasCompletedWelcome = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var backgroundDrift = false
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            welcomeBackground

            GeometryReader { geometry in
                let contentWidth = min(geometry.size.width - 44, 520)

                ScrollView {
                    VStack(spacing: 0) {
                        brand
                            .padding(.top, 18)
                            .welcomeEntrance(
                                isVisible: hasAppeared,
                                delay: 0.04,
                                reduceMotion: reduceMotion
                            )

                        Spacer(minLength: 34)

                        introduction
                            .welcomeEntrance(
                                isVisible: hasAppeared,
                                delay: 0.11,
                                reduceMotion: reduceMotion
                            )

                        Spacer(minLength: 30)

                        featureList(width: contentWidth)
                            .welcomeEntrance(
                                isVisible: hasAppeared,
                                delay: 0.19,
                                reduceMotion: reduceMotion
                            )

                        Spacer(minLength: 26)

                        continueButton(width: contentWidth)
                            .welcomeEntrance(
                                isVisible: hasAppeared,
                                delay: 0.28,
                                reduceMotion: reduceMotion
                            )
                    }
                    .padding(.bottom, 20)
                    .frame(
                        minWidth: geometry.size.width,
                        maxWidth: geometry.size.width,
                        minHeight: geometry.size.height
                    )
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(AppTheme.deepIndigo)
        .onAppear(perform: revealWelcome)
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                withAnimation(.none) { backgroundDrift = false }
            } else {
                startAmbientMotion()
            }
        }
    }

    private var welcomeBackground: some View {
        GeometryReader { geometry in
            ZStack {
                Image("PrayerAtmosphere")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(backgroundDrift ? 1.055 : 1.025)
                    .offset(
                        x: backgroundDrift ? -4 : 4,
                        y: backgroundDrift ? -7 : 3
                    )
                    .clipped()

                ambientGlows(in: geometry.size)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.44),
                        Color.white.opacity(0.72),
                        Color.white.opacity(0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func ambientGlows(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.gold.opacity(0.15))
                .frame(width: 210, height: 210)
                .blur(radius: 46)
                .position(
                    x: size.width * 0.12 + (backgroundDrift ? 12 : -6),
                    y: size.height * 0.26 + (backgroundDrift ? -8 : 8)
                )

            Circle()
                .fill(AppTheme.accent.opacity(0.11))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .position(
                    x: size.width * 0.92 + (backgroundDrift ? -10 : 8),
                    y: size.height * 0.72 + (backgroundDrift ? 10 : -8)
                )
        }
    }

    private func revealWelcome() {
        guard !hasAppeared else { return }

        hasAppeared = true
        startAmbientMotion()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            HapticFeedback.impact(.soft, intensity: 0.38)
        }
    }

    private func startAmbientMotion() {
        guard !reduceMotion else { return }

        withAnimation(
            .timingCurve(0.77, 0, 0.175, 1, duration: 7)
                .repeatForever(autoreverses: true)
        ) {
            backgroundDrift = true
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            Text("MUSLIM 5")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .tracking(1.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Muslim 5")
    }

    private var introduction: some View {
        VStack(spacing: 14) {
            Text("Stay close\nto salah.")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .tracking(-1.4)
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .minimumScaleFactor(0.82)

            Text("A simple, private space to help us stay consistent with our five daily prayers.")
                .font(.body)
                .foregroundStyle(AppTheme.deepIndigo.opacity(0.70))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 330)
        }
    }

    private func featureList(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            WelcomeFeatureRow(
                title: "Only 3 MB",
                message: "Light on your phone, made for every day.",
                systemImage: "arrow.down.circle.fill"
            )

            Divider()
                .overlay(AppTheme.deepIndigo.opacity(0.10))
                .padding(.leading, 58)

            WelcomeFeatureRow(
                title: "No ads. Ever.",
                message: "Nothing between you and your worship.",
                systemImage: "eye.slash.fill"
            )

            Divider()
                .overlay(AppTheme.deepIndigo.opacity(0.10))
                .padding(.leading, 58)

            WelcomeFeatureRow(
                title: "Prayer Circle",
                message: "Pray with loved ones, even when you’re apart.",
                systemImage: "person.2.fill"
            )
        }
        .frame(width: width - 32)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: AppTheme.deepIndigo.opacity(0.08), radius: 22, y: 10)
    }

    private func continueButton(width: CGFloat) -> some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text("Let’s begin")
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: width, height: 56)
            .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(WelcomeButtonStyle())
        .accessibilityHint("Opens the Today screen")
    }
}

private struct WelcomeFeatureRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(AppTheme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.deepIndigo.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}

private struct WelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(
                .timingCurve(0.23, 1, 0.32, 1, duration: 0.14),
                value: configuration.isPressed
            )
    }
}

private struct WelcomeEntranceModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 14)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.985)
            .animation(entranceAnimation, value: isVisible)
    }

    private var entranceAnimation: Animation {
        if reduceMotion {
            return .linear(duration: 0.10)
        }

        return .timingCurve(0.23, 1, 0.32, 1, duration: 0.56)
            .delay(delay)
    }
}

private extension View {
    func welcomeEntrance(
        isVisible: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        modifier(
            WelcomeEntranceModifier(
                isVisible: isVisible,
                delay: delay,
                reduceMotion: reduceMotion
            )
        )
    }
}

#Preview {
    WelcomeView {}
}
