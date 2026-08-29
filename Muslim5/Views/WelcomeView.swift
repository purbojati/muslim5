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
            background

            GeometryReader { geometry in
                let contentWidth = min(geometry.size.width - 48, 520)
                let compactHeight = geometry.size.height < 720

                VStack(spacing: 0) {
                    brand
                        .padding(.top, compactHeight ? 8 : 14)
                        .welcomeEntrance(
                            isVisible: hasAppeared,
                            delay: 0.03,
                            reduceMotion: reduceMotion
                        )

                    Spacer(minLength: compactHeight ? 16 : 28)

                    headline(compactHeight: compactHeight)
                        .welcomeEntrance(
                            isVisible: hasAppeared,
                            delay: 0.10,
                            reduceMotion: reduceMotion
                        )

                    Spacer(minLength: compactHeight ? 16 : 24)

                    highlights
                        .opacity(hasAppeared ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? .linear(duration: 0.10)
                                : .timingCurve(0.23, 1, 0.32, 1, duration: 0.40)
                                    .delay(0.18),
                            value: hasAppeared
                        )

                    Spacer(minLength: compactHeight ? 135 : 230)

                    continueButton(width: contentWidth)
                        .welcomeEntrance(
                            isVisible: hasAppeared,
                            delay: 0.27,
                            reduceMotion: reduceMotion
                        )

                    Text("Your prayer history stays on this iPhone.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.ink.opacity(0.74))
                        .padding(.top, 12)
                        .welcomeEntrance(
                            isVisible: hasAppeared,
                            delay: 0.31,
                            reduceMotion: reduceMotion
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
            }
        }
        .onAppear(perform: revealWelcome)
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                withAnimation(.none) {
                    backgroundDrift = false
                }
            } else {
                startAmbientMotion()
            }
        }
    }

    private var background: some View {
        GeometryReader { geometry in
            Image("OnboardingMountain")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(backgroundDrift ? 1.035 : 1.012)
                .offset(
                    x: backgroundDrift ? -3 : 3,
                    y: backgroundDrift ? -5 : 2
                )
                .overlay {
                    LinearGradient(
                        colors: [
                            AppTheme.ink.opacity(0.15),
                            Color.clear,
                            AppTheme.parchment.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            Image("BrandMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppTheme.parchment)
                .frame(width: 34, height: 34)

            Text("MUSLIM 5")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(AppTheme.parchment)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Muslim 5")
    }

    private func headline(compactHeight: Bool) -> some View {
        ZStack {
            decorativeSymbol(
                "leaf.fill",
                color: AppTheme.warmOrange,
                size: compactHeight ? 24 : 28,
                rotation: -28,
                x: compactHeight ? -108 : -132,
                y: compactHeight ? -96 : -110,
                drift: CGSize(width: 3, height: -4),
                rotationDrift: 4,
                duration: 3.8
            )

            decorativeSymbol(
                "camera.macro",
                color: AppTheme.gold,
                size: compactHeight ? 25 : 29,
                rotation: -10,
                x: compactHeight ? -118 : -142,
                y: compactHeight ? 58 : 66,
                drift: CGSize(width: -3, height: 3),
                rotationDrift: -5,
                duration: 4.4
            )

            decorativeSymbol(
                "moon.stars.fill",
                color: AppTheme.warmOrange.opacity(0.92),
                size: compactHeight ? 23 : 27,
                rotation: 12,
                x: compactHeight ? 112 : 137,
                y: compactHeight ? -29 : -34,
                drift: CGSize(width: 2, height: -4),
                rotationDrift: 3,
                duration: 3.4
            )

            VStack(spacing: compactHeight ? -5 : -3) {
                Text("Stay close")
                Text("to salah,")
                Text("a little more")
                Text("every day.")
                    .foregroundStyle(AppTheme.parchment.opacity(0.66))
            }
            .font(
                .system(
                    size: compactHeight ? 42 : 48,
                    weight: .semibold,
                    design: .serif
                )
            )
            .tracking(-1.3)
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.parchment)
            .shadow(
                color: AppTheme.ink.opacity(0.58),
                radius: 2.5,
                y: 2
            )
            .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stay close to salah, a little more every day.")
    }

    private func decorativeSymbol(
        _ systemName: String,
        color: Color,
        size: CGFloat,
        rotation: Double,
        x: CGFloat,
        y: CGFloat,
        drift: CGSize,
        rotationDrift: Double,
        duration: Double
    ) -> some View {
        let isDrifting = backgroundDrift && !reduceMotion
        let driftDirection: CGFloat = isDrifting ? 1 : -1

        return Image(systemName: systemName)
            .font(.system(size: size, weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .rotationEffect(
                .degrees(
                    rotation
                        + (reduceMotion
                            ? 0
                            : rotationDrift * Double(driftDirection))
                )
            )
            .offset(
                x: x + (reduceMotion ? 0 : drift.width * driftDirection),
                y: y + (reduceMotion ? 0 : drift.height * driftDirection)
            )
            .animation(
                reduceMotion
                    ? nil
                    : .timingCurve(0.77, 0, 0.175, 1, duration: duration)
                        .repeatForever(autoreverses: true),
                value: isDrifting
            )
            .accessibilityHidden(true)
    }

    private var highlights: some View {
        HStack(spacing: 8) {
            highlight("Only 3 MB", systemImage: "arrow.down.circle.fill")
            highlight("No ads", systemImage: "eye.slash.fill")
            highlight("Salah Circle", systemImage: "person.2.fill")
        }
        .frame(maxWidth: 360)
    }

    private func highlight(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.parchment.opacity(0.92))
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(
            AppTheme.ink.opacity(0.52),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(AppTheme.parchment.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func continueButton(width: CGFloat) -> some View {
        Button(action: onContinue) {
            HStack(spacing: 9) {
                Text("Begin")
                    .opacity(
                        reduceMotion ? 1 : (backgroundDrift ? 1 : 0.86)
                    )
                    .scaleEffect(
                        reduceMotion ? 1 : (backgroundDrift ? 1.015 : 0.985)
                    )
                    .animation(
                        reduceMotion
                            ? nil
                            : .timingCurve(0.77, 0, 0.175, 1, duration: 1.9)
                                .repeatForever(autoreverses: true),
                        value: backgroundDrift
                    )
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .font(.headline)
            .foregroundStyle(AppTheme.ink)
            .frame(width: width, height: 62)
            .background(
                Color(red: 0.99, green: 0.98, blue: 0.94),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.parchment.opacity(0.88), lineWidth: 1)
            }
            .shadow(
                color: AppTheme.ink.opacity(0.16),
                radius: 18,
                y: 8
            )
        }
        .buttonStyle(WelcomeButtonStyle())
        .accessibilityHint("Opens the Today screen")
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
            .timingCurve(0.77, 0, 0.175, 1, duration: 8)
                .repeatForever(autoreverses: true)
        ) {
            backgroundDrift = true
        }
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
