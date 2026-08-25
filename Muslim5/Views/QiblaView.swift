import CoreLocation
import SwiftUI
import UIKit

struct QiblaView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var locationProvider: LocationProvider
    @StateObject private var headingProvider = HeadingProvider()
    @State private var alignmentHapticArmed = true
    @State private var alignmentPulseTrigger = 0
    @State private var refreshRotation = 0.0
    @State private var refreshOpacity = 1.0
    @State private var refreshFeedbackTask: Task<Void, Never>?

    private let alignmentTolerance = 3.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    locationHeader

                    if let coordinate = locationProvider.coordinate {
                        compassContent(for: coordinate)
                            .transition(compassTransition)
                    } else {
                        locationStateContent
                            .transition(locationStateTransition)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Qibla")
        }
        .onAppear {
            locationProvider.start()
            headingProvider.start()
        }
        .onDisappear {
            headingProvider.stop()
            refreshFeedbackTask?.cancel()

            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                refreshOpacity = 1
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                locationProvider.requestLocation()
                headingProvider.start()
            } else {
                headingProvider.stop()
            }
        }
        .onChange(of: turn) { _, newTurn in
            guard let newTurn else { return }

            if abs(newTurn) <= alignmentTolerance, alignmentHapticArmed {
                HapticFeedback.notification(.success)
                alignmentPulseTrigger += 1
                alignmentHapticArmed = false
            } else if abs(newTurn) >= 8 {
                alignmentHapticArmed = true
            }
        }
    }

    private var locationHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(locationProvider.cityName ?? "Current location")
                    .font(.headline)
                Text("Calculated privately on this iPhone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                locationProvider.requestLocation()
                HapticFeedback.selection()
                playRefreshFeedback()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(refreshRotation))
                    .opacity(refreshOpacity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Update location")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func compassContent(for coordinate: CLLocationCoordinate2D) -> some View {
        let bearing = QiblaCalculator.bearing(from: coordinate)

        VStack(spacing: 18) {
            QiblaCompass(
                heading: headingProvider.heading ?? 0,
                qiblaBearing: bearing,
                isAligned: isAligned,
                alignmentPulseTrigger: alignmentPulseTrigger
            )
            .frame(maxWidth: 360)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Qibla compass")
            .accessibilityValue(accessibilityGuidance(for: bearing))

            VStack(spacing: 6) {
                Text(guidance(for: bearing))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(isAligned ? AppTheme.success : .primary)
                    .contentTransition(.numericText())

                Text("Qibla is \(Int(bearing.rounded()))° \(cardinalDirection(for: bearing))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .multilineTextAlignment(.center)

            sensorStatus

            Label("Hold your iPhone flat with its top edge pointing forward.", systemImage: "iphone")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var sensorStatus: some View {
        switch headingProvider.state {
        case .idle where headingProvider.heading == nil,
             .updating where headingProvider.heading == nil:
            HStack(spacing: 8) {
                ProgressView()
                Text("Starting compass…")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

        case .unavailable:
            Label("Live compass direction isn’t available on this device.", systemImage: "exclamationmark.compass")
                .font(.footnote)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)

        case .updating where hasLowAccuracy:
            Label("Compass accuracy is low. Move away from metal or electronics and make a figure eight.", systemImage: "wave.3.right.circle")
                .font(.footnote)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var locationStateContent: some View {
        VStack(spacing: 18) {
            Image(systemName: locationProvider.state == .denied ? "location.slash.fill" : "location.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(AppTheme.accent)

            VStack(spacing: 8) {
                Text(locationStateTitle)
                    .font(.title2.bold())
                Text(locationStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if locationProvider.state == .requesting {
                ProgressView()
            } else if locationProvider.state == .denied {
                Button("Open iPhone Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Try Again") {
                    locationProvider.start()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 48)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    private var qiblaBearing: CLLocationDirection? {
        locationProvider.coordinate.map { coordinate in
            QiblaCalculator.bearing(from: coordinate)
        }
    }

    private var turn: CLLocationDirection? {
        guard let heading = headingProvider.heading, let qiblaBearing else { return nil }
        return QiblaCalculator.signedTurn(from: heading, to: qiblaBearing)
    }

    private var isAligned: Bool {
        guard let turn else { return false }
        return abs(turn) <= alignmentTolerance
    }

    private var hasLowAccuracy: Bool {
        guard let accuracy = headingProvider.accuracy else { return false }
        return accuracy > 20
    }

    private func guidance(for bearing: CLLocationDirection) -> String {
        guard let turn else { return "Point toward \(Int(bearing.rounded()))°" }
        let amount = Int(abs(turn).rounded())

        if abs(turn) <= alignmentTolerance {
            return "You’re facing the Qibla"
        }

        return "Turn \(amount)° \(turn > 0 ? "right" : "left")"
    }

    private func accessibilityGuidance(for bearing: CLLocationDirection) -> String {
        "Qibla is \(Int(bearing.rounded())) degrees \(cardinalDirection(for: bearing)). \(guidance(for: bearing))."
    }

    private func cardinalDirection(for bearing: CLLocationDirection) -> String {
        let directions = [
            "north", "northeast", "east", "southeast",
            "south", "southwest", "west", "northwest"
        ]
        let index = Int((QiblaCalculator.normalize(bearing) + 22.5) / 45) % directions.count
        return directions[index]
    }

    private var locationStateTitle: String {
        switch locationProvider.state {
        case .denied: "Location is off"
        case .unavailable: "Location unavailable"
        default: "Finding your location"
        }
    }

    private var locationStateMessage: String {
        switch locationProvider.state {
        case .denied:
            "Allow location access in Settings to calculate the Qibla direction."
        case .unavailable:
            "We couldn’t get your location. Check Location Services and try again."
        default:
            "Your position is needed to calculate the direction toward the Kaaba."
        }
    }

    private var compassTransition: AnyTransition {
        let insertion = reduceMotion
            ? AnyTransition.opacity
            : AnyTransition.opacity.combined(with: .scale(scale: 0.97))

        return .asymmetric(
            insertion: insertion.animation(.easeOut(duration: 0.2)),
            removal: .opacity.animation(.easeOut(duration: 0.14))
        )
    }

    private var locationStateTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.2)),
            removal: .opacity.animation(.easeOut(duration: 0.14))
        )
    }

    private func playRefreshFeedback() {
        refreshFeedbackTask?.cancel()

        if reduceMotion {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                refreshOpacity = 1
            }

            refreshFeedbackTask = Task { @MainActor in
                withAnimation(.easeOut(duration: 0.07)) {
                    refreshOpacity = 0.55
                }

                do {
                    try await Task.sleep(for: .milliseconds(70))
                } catch {
                    return
                }

                withAnimation(.easeOut(duration: 0.07)) {
                    refreshOpacity = 1
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.24)) {
                refreshRotation += 360
            }
        }
    }
}

private struct QiblaCompass: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let heading: CLLocationDirection
    let qiblaBearing: CLLocationDirection
    let isAligned: Bool
    let alignmentPulseTrigger: Int

    @State private var puckScale: CGFloat = 1
    @State private var haloScale: CGFloat = 0.75
    @State private var haloOpacity = 0.0
    @State private var pulseTask: Task<Void, Never>?

    private var turn: CLLocationDirection {
        QiblaCalculator.signedTurn(from: heading, to: qiblaBearing)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                Circle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                Circle()
                    .stroke(AppTheme.accent.opacity(0.12), lineWidth: 12)
                    .padding(8)

                compassRose
                    .rotationEffect(.degrees(-heading))

                qiblaMarker(size: size)
                    .rotationEffect(.degrees(turn))

                ZStack {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 38, height: 38)
                        .scaleEffect(haloScale)
                        .opacity(haloOpacity)
                        .allowsHitTesting(false)

                    Circle()
                        .fill(isAligned ? AppTheme.success : AppTheme.accent)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        .scaleEffect(puckScale)
                }
            }
            .frame(width: size, height: size)
        }
        .onChange(of: alignmentPulseTrigger) { _, _ in
            playAlignmentPulse()
        }
        .onDisappear {
            pulseTask?.cancel()

            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                puckScale = 1
                haloScale = reduceMotion ? 1 : 0.75
                haloOpacity = 0
            }
        }
    }

    private var compassRose: some View {
        ZStack {
            ForEach(0..<72, id: \.self) { index in
                VStack {
                    Capsule()
                        .fill(index % 6 == 0 ? Color.primary.opacity(0.65) : Color.secondary.opacity(0.28))
                        .frame(width: index % 6 == 0 ? 2.5 : 1.2, height: index % 6 == 0 ? 13 : 7)
                        .padding(.top, 18)
                    Spacer()
                }
                .rotationEffect(.degrees(Double(index) * 5))
            }

            VStack {
                cardinalLabel("N", color: AppTheme.accent)
                Spacer()
                cardinalLabel("S")
            }
            .padding(.vertical, 42)

            HStack {
                cardinalLabel("W")
                Spacer()
                cardinalLabel("E")
            }
            .padding(.horizontal, 42)
        }
    }

    private func cardinalLabel(_ label: String, color: Color = .secondary) -> some View {
        Text(label)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(color)
    }

    private func qiblaMarker(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            KaabaSymbol()
                .frame(width: 38, height: 38)

            Rectangle()
                .fill(isAligned ? AppTheme.success : AppTheme.gold)
                .frame(width: 3, height: max(36, size / 2 - 73))

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }

    private func playAlignmentPulse() {
        pulseTask?.cancel()

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            puckScale = 1
            haloScale = reduceMotion ? 1 : 0.75
            haloOpacity = 0.32
        }

        pulseTask = Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.14)) {
                    haloOpacity = 0
                }
                return
            }

            withAnimation(.easeOut(duration: 0.12)) {
                puckScale = 1.16
            }
            withAnimation(.easeOut(duration: 0.28)) {
                haloScale = 1.3
                haloOpacity = 0
            }

            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }

            withAnimation(.easeOut(duration: 0.12)) {
                puckScale = 1
            }
        }
    }
}

private struct KaabaSymbol: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.black)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppTheme.gold)
                    .frame(height: 6)
                    .padding(.top, 8)
            }
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}
