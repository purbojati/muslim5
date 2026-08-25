import SwiftUI

struct PrayerHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let phase: PrayerPhase?
    let date: Date
    let locationState: LocationProvider.State
    let onLocationAction: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                if let phase {
                    activeContent(phase)
                } else {
                    locationContent
                }
            }
            .id(contentIdentity)
            .transition(contentTransition)
        }
        .animation(contentAnimation, value: contentIdentity)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 156)
    }

    private var contentIdentity: HeroContentIdentity {
        guard phase == nil else { return .activePrayer }

        return switch locationState {
        case .requesting: .requesting
        case .denied: .denied
        case .idle: .idle
        case .ready, .unavailable: .unavailable
        }
    }

    private var contentTransition: AnyTransition {
        let insertion = AnyTransition.opacity
            .combined(with: reduceMotion ? .identity : .offset(y: 6))
            .animation(contentAnimation)
        let removal = AnyTransition.opacity
            .animation(.easeOut(duration: reduceMotion ? 0.16 : 0.2))

        return .asymmetric(insertion: insertion, removal: removal)
    }

    private var contentAnimation: Animation {
        .easeOut(duration: reduceMotion ? 0.16 : 0.25)
    }

    private func activeContent(_ phase: PrayerPhase) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(phase.countdownText(at: date))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: phase.progress(at: date))
                .tint(.white)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())

            HStack {
                phaseStartLabel(phase)

                Spacer()

                Text("\(phase.boundaryName) ") +
                    Text(phase.end, format: .dateTime.hour().minute())
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.76))
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(phase.title). \(phase.accessibilityCountdownText(at: date)). " +
            "\(phase.boundaryName) at \(phase.end.formatted(date: .omitted, time: .shortened))."
        )
    }

    @ViewBuilder
    private func phaseStartLabel(_ phase: PrayerPhase) -> some View {
        switch phase.kind {
        case .active:
            Text(phase.start, format: .dateTime.hour().minute())
                .monospacedDigit()
        case .upcoming:
            Text("Now ") + Text(date, format: .dateTime.hour().minute()).monospacedDigit()
        }
    }

    @ViewBuilder
    private var locationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if locationState == .requesting {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
                Text("Finding your prayer times")
                    .font(.title3.bold())
                Text("Using your location only on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                Image(systemName: locationState == .denied ? "location.slash.fill" : "location.fill")
                    .font(.system(size: 25, weight: .semibold))

                Text(locationState == .denied ? "Location access is off" : "Find your local prayer times")
                    .font(.title3.bold())

                Text(locationState == .denied
                     ? "Allow location in Settings to calculate the prayer windows around you."
                     : "Your coordinates stay on this device and are used for offline calculation.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)

                Button(action: onLocationAction) {
                    Label(locationState == .denied ? "Open Settings" : "Try location again", systemImage: "location.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .foregroundStyle(AppTheme.deepIndigo)
                }
                .buttonStyle(PrayerHeroButtonStyle())
            }
        }
        .foregroundStyle(.white)
        .frame(minHeight: 156)
    }
}

private enum HeroContentIdentity: Hashable {
    case activePrayer
    case requesting
    case denied
    case idle
    case unavailable
}

private struct PrayerHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
