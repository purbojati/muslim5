import SwiftUI
import UIKit

struct SalahFocusSettingsView: View {
    @EnvironmentObject private var salahFocusService: SalahFocusService
    @State private var isOnboardingPresented = false

    var body: some View {
        Group {
            if salahFocusService.isAuthorized {
                SalahFocusControlView {
                    isOnboardingPresented = true
                }
            } else {
                SalahFocusOnboardingView(isReview: false)
            }
        }
        .onAppear {
            salahFocusService.refreshAuthorizationStatus()
        }
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            NavigationStack {
                SalahFocusOnboardingView(isReview: true)
            }
            .environmentObject(salahFocusService)
        }
    }
}

private struct SalahFocusControlView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var salahFocusService: SalahFocusService
    let showOnboarding: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                statusCard

                if let prayerName = salahFocusService.activePrayerName,
                   salahFocusService.isEnabled {
                    activePrayerCard(prayerName: prayerName)
                }

                controlCard
                reminderCard

                Button(action: showOnboarding) {
                    Label("See how Salah Focus works", systemImage: "play.rectangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.salahFocusFeature)

                if let error = salahFocusService.lastError {
                    errorCard(message: error)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Salah Focus")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusCard: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(AppTheme.salahFocusFeature.opacity(0.12))
                    .frame(width: 78, height: 78)

                Image(systemName: salahFocusService.isEnabled ? "checkmark.shield.fill" : "lock.slash.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.salahFocusFeature)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityHidden(true)

            Text(
                salahFocusService.isEnabled
                    ? String(localized: "Ready for the next salah")
                    : String(localized: "Salah Focus is off")
            )
                .font(.system(.title2, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)

            Text(
                salahFocusService.isEnabled
                    ? String(localized: "Ordinary apps will pause when your next unfinished prayer begins.")
                    : String(localized: "Turn it on below whenever you want apps to pause at prayer time.")
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .salahFocusCard()
    }

    private var controlCard: some View {
        VStack(spacing: 14) {
            Toggle(isOn: enabledBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Salah Focus")
                        .font(.headline)
                    Text(
                        salahFocusService.isEnabled
                            ? String(localized: "On")
                            : String(localized: "Off")
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.salahFocusFeature)

            Divider()

            LabeledContent {
                Text("All ordinary apps")
                    .foregroundStyle(.secondary)
            } label: {
                Label("Coverage", systemImage: "square.grid.2x2.fill")
            }

            LabeledContent {
                Text("After you mark salah complete")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Unlocks", systemImage: "lock.open.fill")
            }
        }
        .padding(18)
        .salahFocusCard()
    }

    private func activePrayerCard(prayerName: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "hourglass.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.warmOrange)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(prayerName) Focus is active")
                    .font(.headline)
                Text("Complete \(prayerName), then tap \(prayerName) on Today to unlock your apps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.warmOrange.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.warmOrange.opacity(0.24), lineWidth: 1)
        }
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("A gentle reminder", systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.salahFocusFeature)

            Text("“The most beloved deed to Allah is prayer at its proper time.”")
                .font(.system(.body, design: .serif, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text("Sahih al-Bukhari 527")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .salahFocusCard()
        .accessibilityElement(children: .combine)
    }

    private func errorCard(message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { salahFocusService.isEnabled },
            set: { newValue in
                if newValue {
                    if salahFocusService.enable() {
                        HapticFeedback.notification(.success)
                    } else {
                        HapticFeedback.notification(.warning)
                    }
                } else {
                    salahFocusService.disable()
                    HapticFeedback.impact(.soft)
                }
            }
        )
    }
}

private struct SalahFocusOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var salahFocusService: SalahFocusService
    @State private var page = 0
    @State private var isRequestingAuthorization = false
    let isReview: Bool

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                purposePage.tag(0)
                previewPage.tag(1)
                permissionPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 14) {
                pageIndicator
                primaryAction

                if page == 2,
                   salahFocusService.authorizationStatus == .denied {
                    Button("Open iPhone Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Salah Focus setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isReview {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var purposePage: some View {
        OnboardingPage {
            VStack(spacing: 22) {
                SalahFocusFlowIllustration()

                VStack(spacing: 9) {
                    Text("Pause distractions for salah")
                        .font(.system(.title, design: .serif, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("Other apps pause until you record your prayer in Muslim 5.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var previewPage: some View {
        OnboardingPage {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("A simple reminder")
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text("It names the prayer and opens Muslim 5 when you’re ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SalahFocusShieldPreview(prayerName: String(localized: "Dhuhr"))
            }
        }
    }

    private var permissionPage: some View {
        OnboardingPage {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.salahFocusFeature)

                VStack(spacing: 8) {
                    Text("Allow Screen Time")
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text("Apple requires this permission to pause apps. Muslim 5 cannot see your Screen Time activity.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    safetyRow(
                        String(localized: "Muslim 5, calls, and emergency access stay available"),
                        icon: "checkmark.circle.fill"
                    )
                    safetyRow(String(localized: "Turn Salah Focus off anytime"), icon: "switch.2")
                }
                .padding(.horizontal, 4)

                if let error = salahFocusService.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AppTheme.salahFocusFeature : Color.secondary.opacity(0.22))
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(
            reduceMotion ? .linear(duration: 0.1) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.2),
            value: page
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(page + 1) of 3")
    }

    @ViewBuilder
    private var primaryAction: some View {
        if page < 2 {
            Button {
                withAnimation(
                    reduceMotion
                        ? .linear(duration: 0.1)
                        : .timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
                ) {
                    page += 1
                }
            } label: {
                onboardingButtonLabel(String(localized: "Continue"), icon: "arrow.right")
            }
            .buttonStyle(SalahFocusPrimaryButtonStyle())
        } else if isReview || salahFocusService.isAuthorized {
            Button { dismiss() } label: {
                onboardingButtonLabel(String(localized: "Done"), icon: "checkmark")
            }
            .buttonStyle(SalahFocusPrimaryButtonStyle())
        } else {
            Button(action: requestAuthorization) {
                onboardingButtonLabel(
                    isRequestingAuthorization
                        ? String(localized: "Waiting for iPhone…")
                        : String(localized: "Turn On Salah Focus"),
                    icon: isRequestingAuthorization ? nil : "lock.open.fill",
                    showsProgress: isRequestingAuthorization
                )
            }
            .buttonStyle(SalahFocusPrimaryButtonStyle())
            .disabled(isRequestingAuthorization)
        }
    }

    private func onboardingButtonLabel(
        _ title: String,
        icon: String?,
        showsProgress: Bool = false
    ) -> some View {
        HStack(spacing: 9) {
            if showsProgress {
                ProgressView().tint(.white)
            } else if let icon {
                Image(systemName: icon)
            }
            Text(title)
            if title == String(localized: "Continue") {
                Spacer(minLength: 0)
            }
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(AppTheme.salahFocusFeature, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func safetyRow(_ text: String, icon: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.salahFocusFeature)
                .frame(width: 22)
        }
    }

    private func requestAuthorization() {
        isRequestingAuthorization = true
        Task {
            let allowed = await salahFocusService.requestAuthorization()
            isRequestingAuthorization = false
            if allowed, salahFocusService.enable() {
                HapticFeedback.notification(.success)
                if isReview { dismiss() }
            } else {
                HapticFeedback.notification(.warning)
            }
        }
    }
}

private struct OnboardingPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
        }
    }
}

private struct SalahFocusFlowIllustration: View {
    var body: some View {
        HStack(spacing: 15) {
            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    appTile("camera.fill", color: .pink)
                    appTile("message.fill", color: .green)
                }
                HStack(spacing: 6) {
                    appTile("play.fill", color: .red)
                    appTile("globe", color: .blue)
                }
            }

            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.salahFocusFeature.opacity(0.12))
                    .frame(width: 92, height: 106)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.salahFocusFeature)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .salahFocusCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ordinary apps pause so you can make time for salah")
    }

    private func appTile(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 45, height: 45)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SalahFocusShieldPreview: View {
    let prayerName: String

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.72))
                .frame(width: 82, height: 24)
                .padding(.top, 10)

            Spacer(minLength: 16)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color(red: 0.91, green: 0.64, blue: 0.25))

            Text("Make space for \(prayerName)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.88))
                .padding(.top, 15)

            Text("“Prayer at its proper time.”\n— Sahih al-Bukhari 527")
                .font(.footnote)
                .foregroundStyle(Color(red: 0.82, green: 0.84, blue: 0.78))
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Text("Pray \(prayerName), then mark it complete in Muslim 5 to unlock your apps.")
                .font(.footnote)
                .foregroundStyle(Color(red: 0.82, green: 0.84, blue: 0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 12)

            Spacer(minLength: 16)

            Text("I’ve prayed — open Muslim 5")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color(red: 0.025, green: 0.035, blue: 0.035))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(red: 0.91, green: 0.64, blue: 0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 18)

            Text("Snooze for 30 minutes")
                .font(.caption)
                .foregroundStyle(Color(red: 0.82, green: 0.84, blue: 0.78))
                .padding(.top, 13)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: 300)
        .frame(height: 390)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.095, blue: 0.035),
                    Color(red: 0.07, green: 0.035, blue: 0.015)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 20, y: 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview. Make space for Dhuhr. Pray Dhuhr, then mark it complete in Muslim 5 to unlock your apps.")
    }
}

private struct SalahFocusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                .timingCurve(0.23, 1, 0.32, 1, duration: 0.14),
                value: configuration.isPressed
            )
    }
}

private extension View {
    func salahFocusCard() -> some View {
        background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}
