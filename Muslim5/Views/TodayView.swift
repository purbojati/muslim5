import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var locationProvider: LocationProvider
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"
    @State private var dayOffset = 0
    private let prayerScheduleService = PrayerScheduleService()

    private var metrics: ProgressMetrics { ProgressMetrics(records: records, pauses: pauses) }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let selectedDate = Calendar.autoupdatingCurrent.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: timeline.date
                ) ?? timeline.date

                homepage(at: selectedDate)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: locationProvider.state) { oldState, newState in
            guard oldState != newState else { return }

            switch newState {
            case .ready where oldState == .requesting:
                HapticFeedback.notification(.success)
            case .denied:
                HapticFeedback.notification(.warning)
            case .unavailable:
                HapticFeedback.notification(.error)
            default:
                break
            }
        }
    }

    @ViewBuilder
    private func homepage(at date: Date) -> some View {
        let schedule = makeSchedule(at: date)
        let phase = schedule?.phase(at: date)
        let hijriDate = hijriDisplayDate(
            for: date,
            maghrib: schedule?.today.maghrib
        )

        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    prayerHeader(
                        at: date,
                        hijriDate: hijriDate,
                        phase: phase,
                        topInset: geometry.safeAreaInsets.top
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        dailyCompanionCard(for: date)

                        if periodMode {
                            pauseBanner
                        }

                        prayerList(schedule: schedule?.today, on: date)
                        gentleFooter(for: date)
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

    private func prayerHeader(
        at date: Date,
        hijriDate: Date,
        phase: PrayerPhase?,
        topInset: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            PrayerSkyBackground(scene: previewScene ?? phase?.scene ?? fallbackScene(at: date))

            VStack(alignment: .leading, spacing: 26) {
                dayHeader(at: hijriDate)

                if dayOffset == 0 {
                    PrayerHeroView(
                        phase: phase,
                        date: date,
                        locationState: locationProvider.state,
                        onLocationAction: handleLocationAction
                    )
                } else {
                    historicalReviewPrompt
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset + 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minHeight: (dayOffset == 0 ? 332 : 224) + topInset,
            alignment: .topLeading
        )
    }

    private func hijriDisplayDate(for date: Date, maghrib: Date?) -> Date {
        guard let maghrib, date >= maghrib else { return date }
        return Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private var historicalReviewPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Complete this day’s checklist", systemImage: "clock.arrow.circlepath")
                .font(.title3.bold())
            Text("Add any prayers you completed but forgot to record.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayHeader(at date: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dayTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(date.formatted(hijriDateFormat))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            locationControl
        }
        .foregroundStyle(.white)
    }

    private var dayTitle: String {
        switch dayOffset {
        case 0: "Today"
        case -1: "Yesterday"
        default: "\(abs(dayOffset)) days ago"
        }
    }

    private func changeDay(by amount: Int) {
        guard dayOffset + amount <= 0 else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            dayOffset += amount
        }
        HapticFeedback.selection()
    }

    private var hijriDateFormat: Date.FormatStyle {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = .autoupdatingCurrent

        return Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: locale,
            calendar: calendar
        )
        .weekday(.wide)
        .month(.wide)
        .day()
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

    private func dailyCompanionCard(for date: Date) -> some View {
        let completedCount = metrics.completedCount(on: date)

        return VStack(alignment: .leading, spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    completionCount(on: date)
                    streakStatus
                }
            } else {
                HStack {
                    completionCount(on: date)
                    Spacer()
                    streakStatus
                }
            }

            ProgressView(value: Double(completedCount), total: 5)
                .tint(completedCount == 5 ? AppTheme.success : AppTheme.accent)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private func completionCount(on date: Date) -> some View {
        Text("\(metrics.completedCount(on: date)) of 5 \(dayOffset == 0 ? "today" : "on this day")")
            .font(.headline)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private var streakStatus: some View {
        Text(dayOffset == 0 ? streakMessage : "Reviewing past day")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func prayerList(schedule: DailyPrayerSchedule?, on date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Your five moments")
                        .font(.title3.bold())

                    Spacer()

                    checklistDayNavigation
                }

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
                    record: metrics.record(for: prayer, on: date),
                    isEnabled: !periodMode,
                    onToggle: { toggle(prayer, on: date) },
                    onStatusChange: { setStatus($0, for: prayer, on: date) },
                    onAttendanceChange: { setAttendance($0, for: prayer, on: date) }
                )
            }
        }
    }

    private var checklistDayNavigation: some View {
        HStack(spacing: 2) {
            checklistDayButton(
                systemImage: "chevron.left",
                accessibilityLabel: "Previous day"
            ) {
                changeDay(by: -1)
            }

            Text(dayTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minWidth: 48)
                .contentTransition(.numericText())

            checklistDayButton(
                systemImage: "chevron.right",
                accessibilityLabel: "Next day",
                isEnabled: dayOffset < 0
            ) {
                changeDay(by: 1)
            }
        }
        .padding(3)
        .foregroundStyle(AppTheme.accent)
        .background(AppTheme.accent.opacity(0.1), in: Capsule())
    }

    private func checklistDayButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(systemImage == "chevron.left" ? "Shows an earlier checklist" : "Shows a more recent checklist")
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

    private func gentleFooter(for date: Date) -> some View {
        let isComplete = metrics.completedCount(on: date) == Prayer.allCases.count

        return HStack(spacing: 14) {
            Image(systemName: isComplete ? "sparkles" : "heart.fill")
                .foregroundStyle(isComplete ? AppTheme.gold : AppTheme.accent)

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

    private func toggle(_ prayer: Prayer, on date: Date) {
        let existingRecord = metrics.record(for: prayer, on: date)
        let willCompleteDay = existingRecord == nil && metrics.completedCount(on: date) == Prayer.allCases.count - 1

        withAnimation(.easeOut(duration: 0.2)) {
            if let record = existingRecord {
                modelContext.delete(record)
            } else {
                modelContext.insert(PrayerRecord(day: date, prayer: prayer, status: .completed))
            }
        }

        guard save() else {
            HapticFeedback.notification(.error)
            return
        }

        if existingRecord != nil {
            HapticFeedback.impact(.soft, intensity: 0.7)
        } else if willCompleteDay {
            HapticFeedback.notification(.success)
        } else {
            HapticFeedback.impact(.medium)
        }
    }

    private func setStatus(_ status: PrayerStatus, for prayer: Prayer, on date: Date) {
        if let record = metrics.record(for: prayer, on: date) {
            record.status = status
            record.recordedAt = .now
        } else {
            modelContext.insert(PrayerRecord(day: date, prayer: prayer, status: status))
        }
        if save() {
            HapticFeedback.selection()
        } else {
            HapticFeedback.notification(.error)
        }
    }

    private func setAttendance(_ attendance: PrayerAttendance, for prayer: Prayer, on date: Date) {
        if let record = metrics.record(for: prayer, on: date) {
            record.attendance = attendance
            record.recordedAt = .now
        } else {
            modelContext.insert(
                PrayerRecord(
                    day: date,
                    prayer: prayer,
                    status: .completed,
                    attendance: attendance
                )
            )
        }
        if save() {
            HapticFeedback.selection()
        } else {
            HapticFeedback.notification(.error)
        }
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
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
        HapticFeedback.impact(.light)

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

    private var previewScene: PrayerScene? {
#if DEBUG
        guard let rawValue = ProcessInfo.processInfo.environment["SALAH_PREVIEW_SCENE"] else {
            return nil
        }
        return PrayerScene(rawValue: rawValue)
#else
        return nil
#endif
    }
}
