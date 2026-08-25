import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
    @AppStorage("travelMode") private var travelMode = false
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"
    @StateObject private var locationProvider = LocationProvider()

    private let prayerScheduleService = PrayerScheduleService()

    private var metrics: ProgressMetrics { ProgressMetrics(records: records, pauses: pauses) }
    private var completedToday: Int { metrics.completedCount(on: .now) }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                homepage(at: timeline.date)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            locationProvider.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                locationProvider.requestLocation()
            }
        }
    }

    @ViewBuilder
    private func homepage(at date: Date) -> some View {
        let schedule = makeSchedule(at: date)
        let phase = schedule?.phase(at: date)

        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    prayerHeader(
                        at: date,
                        phase: phase,
                        topInset: geometry.safeAreaInsets.top
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        dailyCompanionCard

                        if periodMode {
                            pauseBanner
                        } else if travelMode {
                            travelBanner
                        }

                        prayerList(schedule: schedule?.today)
                        gentleFooter
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
        }
    }

    private func prayerHeader(at date: Date, phase: PrayerPhase?, topInset: CGFloat) -> some View {
        ZStack {
            PrayerSkyBackground(scene: phase?.scene ?? fallbackScene(at: date))

            VStack(alignment: .leading, spacing: 26) {
                todayHeader(at: date)

                PrayerHeroView(
                    phase: phase,
                    date: date,
                    locationState: locationProvider.state,
                    onLocationAction: handleLocationAction
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset + 12)
            .padding(.bottom, 24)
        }
        .frame(minHeight: 332 + topInset)
    }

    private func todayHeader(at date: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            locationControl
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var locationControl: some View {
        if #available(iOS 26.0, *) {
            locationButton
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            locationButton
                .background(.thinMaterial, in: Capsule())
        }
    }

    private var locationButton: some View {
        Button(action: handleLocationAction) {
            Label(locationLabel, systemImage: locationSymbol)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Updates the location used for prayer times")
    }

    private var locationLabel: String {
        switch locationProvider.state {
        case .requesting: "Locating"
        case .denied: "Location off"
        default: "Local"
        }
    }

    private var locationSymbol: String {
        locationProvider.state == .denied ? "location.slash.fill" : "location.fill"
    }

    private var dailyCompanionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    completionCount
                    streakStatus
                }
            } else {
                HStack {
                    completionCount
                    Spacer()
                    streakStatus
                }
            }

            ProgressView(value: Double(completedToday), total: 5)
                .tint(completedToday == 5 ? AppTheme.success : AppTheme.accent)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private var completionCount: some View {
        Text("\(completedToday) of 5 today")
            .font(.headline)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private var streakStatus: some View {
        Text(streakMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func prayerList(schedule: DailyPrayerSchedule?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your five moments")
                    .font(.title3.bold())
                Text("Tap to complete. Touch and hold for more options.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)

            ForEach(Prayer.allCases) { prayer in
                PrayerRow(
                    prayer: prayer,
                    prayerTime: schedule?.time(for: prayer),
                    record: metrics.record(for: prayer, on: .now),
                    isEnabled: !periodMode,
                    onToggle: { toggle(prayer) },
                    onStatusChange: { setStatus($0, for: prayer) }
                )
            }
        }
    }

    private var pauseBanner: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tracking is respectfully paused")
                    .font(.subheadline.weight(.semibold))
                Text("These days won’t be treated as missed days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var travelBanner: some View {
        Label("Travel mode is on", systemImage: "airplane")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var gentleFooter: some View {
        HStack(spacing: 14) {
            Image(systemName: completedToday == 5 ? "sparkles" : "heart.fill")
                .foregroundStyle(completedToday == 5 ? AppTheme.gold : AppTheme.accent)

            Text("Every return counts—even the quiet ones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 6)
    }

    private var streakMessage: String {
        metrics.currentStreak == 0
            ? "Today is a fresh start"
            : "\(metrics.currentStreak) days in rhythm"
    }

    private func toggle(_ prayer: Prayer) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let record = metrics.record(for: prayer, on: .now) {
                modelContext.delete(record)
            } else {
                modelContext.insert(PrayerRecord(day: .now, prayer: prayer, status: .completed))
            }
            save()
        }
    }

    private func setStatus(_ status: PrayerStatus, for prayer: Prayer) {
        if let record = metrics.record(for: prayer, on: .now) {
            record.status = status
            record.recordedAt = .now
        } else {
            modelContext.insert(PrayerRecord(day: .now, prayer: prayer, status: status))
        }
        save()
    }

    private func save() {
        try? modelContext.save()
    }

    private func makeSchedule(at date: Date) -> PrayerSchedule? {
        guard let coordinate = locationProvider.coordinate else { return nil }
        return prayerScheduleService.schedule(
            for: coordinate,
            at: date,
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
    }

    private func handleLocationAction() {
        if locationProvider.state == .denied,
           let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            openURL(settingsURL)
        } else {
            locationProvider.requestLocation()
        }
    }

    private func fallbackScene(at date: Date) -> PrayerScene {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        return switch hour {
        case 4..<7: .dawn
        case 7..<16: .daylight
        case 16..<18: .goldenHour
        case 18..<20: .dusk
        default: .night
        }
    }
}
