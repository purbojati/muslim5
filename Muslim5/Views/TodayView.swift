import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    private static let hijriMonthNames = [
        "Muharram",
        "Safar",
        "Rabi al-Awwal",
        "Rabi al-Thani",
        "Jumada al-Awwal",
        "Jumada al-Thani",
        "Rajab",
        "Sha'ban",
        "Ramadan",
        "Shawwal",
        "Dhu al-Qi'dah",
        "Dhu al-Hijjah"
    ]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var locationProvider: LocationProvider
    @EnvironmentObject private var salahFocusService: SalahFocusService
    @EnvironmentObject private var sharingService: SharingService
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"
    @State private var dayOffset = 0
    @State private var navigationDirection = -1
    @State private var completionCelebrationDay: Date?
    @State private var focusReleaseConfirmationPrayer: Prayer?
    @State private var focusReleaseConfirmationTask: Task<Void, Never>?
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

                homepage(at: selectedDate, currentDate: timeline.date)
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
        .task(id: sharingSyncKey) {
            await synchronizeSharing(at: selectedDate())
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await synchronizeSharing(at: selectedDate()) }
        }
    }

    @ViewBuilder
    private func homepage(at date: Date, currentDate: Date) -> some View {
        let schedule = makeSchedule(at: date)
        let phase = schedule?.phase(at: date)
        let scene = previewScene ?? phase?.scene ?? fallbackScene(at: date)
        let hijriDate = hijriDisplayDate(
            for: date,
            maghrib: schedule?.today.maghrib
        )

        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    prayerHeaderSection(
                        at: date,
                        hijriDate: hijriDate,
                        phase: phase,
                        scene: scene,
                        topInset: geometry.safeAreaInsets.top
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        if sharingService.isConfigured, sharingService.profile == nil {
                            prayerCircleCard
                        }

                        if periodMode {
                            pauseBanner
                        }

                        prayerList(schedule: schedule, on: date, currentDate: currentDate)

                        checklistDayNavigation
                            .frame(maxWidth: .infinity, alignment: .center)

                        gentleFooter(
                            for: date,
                            schedule: schedule,
                            currentDate: currentDate
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await synchronizeSharing(at: date)
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
        }
    }

    private func prayerHeaderSection(
        at date: Date,
        hijriDate: Date,
        phase: PrayerPhase?,
        scene: PrayerScene,
        topInset: CGFloat
    ) -> some View {
        prayerHeader(
            at: date,
            hijriDate: hijriDate,
            phase: phase,
            scene: scene,
            topInset: topInset
        )
    }

    private func prayerHeader(
        at date: Date,
        hijriDate: Date,
        phase: PrayerPhase?,
        scene: PrayerScene,
        topInset: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            PrayerSkyBackground(scene: scene)

            VStack(alignment: .leading, spacing: 26) {
                dayHeader(at: hijriDate)

                ZStack(alignment: .topLeading) {
                    Group {
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
                    .id(dayOffset)
                    .transition(dayContentTransition)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
            Label("Missed a check-in?", systemImage: "clock.arrow.circlepath")
                .font(.title3.bold())
            Text("Record any salah you prayed on this day.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayHeader(at date: Date) -> some View {
        HStack(alignment: .top) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dayTitle)
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text(hijriDateText(for: date))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .id(dayOffset)
                .transition(dayContentTransition)
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

        completionCelebrationDay = nil
        navigationDirection = amount
        withAnimation(dayChangeAnimation) {
            dayOffset += amount
        }
        HapticFeedback.selection()
    }

    private var dayChangeAnimation: Animation {
        .easeInOut(duration: reduceMotion ? 0.14 : 0.2)
    }

    private var dayContentTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }

        let incomingOffset: CGFloat = navigationDirection < 0 ? -8 : 8
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: incomingOffset)),
            removal: .opacity.combined(with: .offset(x: -incomingOffset))
        )
    }

    private func hijriDateText(for date: Date) -> String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents([.month, .day], from: date)

        let fallbackDate = date.formatted(Date.FormatStyle(
            date: .abbreviated,
            time: .omitted,
            locale: locale,
            calendar: calendar
        ))

        guard
            let month = components.month,
            Self.hijriMonthNames.indices.contains(month - 1),
            let day = components.day
        else {
            return fallbackDate
        }

        return "\(day) \(Self.hijriMonthNames[month - 1])"
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
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: 160)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Prayer time location: \(locationLabel)")
        .accessibilityHint("Updates the location used for prayer times")
    }

    private var locationLabel: String {
        switch locationProvider.state {
        case .requesting: "Locating"
        case .denied: "Location off"
        default: locationProvider.cityName ?? "Locating"
        }
    }

    private var locationSymbol: String {
        locationProvider.state == .denied ? "location.slash.fill" : "location.fill"
    }

    private var prayerCircleCard: some View {
        NavigationLink {
            SharingSettingsView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.14))

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Prayer Circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Pray together, even when apart")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("Set up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.accent.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set up Prayer Circle")
        .accessibilityHint("Opens Prayer Circle setup")
    }

    private func prayerList(
        schedule: PrayerSchedule?,
        on date: Date,
        currentDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your five daily prayers")
                    .font(.title3.bold())

                if metrics.completedCount(on: date) == 0 {
                    Text("Tap after you pray. Touch and hold for more options.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 12) {
                    ForEach(Prayer.allCases) { prayer in
                        PrayerRow(
                            prayer: prayer,
                            prayerTime: schedule?.today.time(for: prayer),
                            record: metrics.record(for: prayer, on: date),
                            linkedUsers: sharingService.users(for: prayer, on: date),
                            isEnabled: !periodMode,
                            hasPrayerTimePassed: hasPrayerTimePassed(
                                prayer,
                                in: schedule,
                                at: currentDate
                            ),
                            onToggle: { toggle(prayer, on: date) },
                            onStatusChange: { setStatus($0, for: prayer, on: date) },
                            onAttendanceChange: { setAttendance($0, for: prayer, on: date) }
                        )
                    }

                    if let prayer = focusReleaseConfirmationPrayer {
                        Label("Apps available again after \(prayer.name)", systemImage: "lock.open.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                    }
                }
                .id(dayOffset)
                .transition(dayContentTransition)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func hasPrayerTimePassed(
        _ prayer: Prayer,
        in schedule: PrayerSchedule?,
        at date: Date
    ) -> Bool {
        guard let schedule else { return false }
        return schedule.hasEnded(prayer, at: date)
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
                .frame(width: 72)
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
                Text("Period Mode is on")
                    .font(.subheadline.weight(.semibold))
                Text("Salah tracking is paused, and these days won’t affect your streak.")
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

    private func gentleFooter(
        for date: Date,
        schedule: PrayerSchedule?,
        currentDate: Date
    ) -> some View {
        let isComplete = metrics.completedCount(on: date) == Prayer.allCases.count
        let celebratesCompletion = isComplete && shouldCelebrateCompletion(on: date)
        let message = gentleFooterMessage(
            for: date,
            schedule: schedule,
            currentDate: currentDate
        )

        return HStack(spacing: 14) {
            ZStack {
                if isComplete {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppTheme.gold)
                        .transition(celebratesCompletion ? sparkleTransition : quietSymbolTransition)
                } else {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppTheme.accent)
                        .transition(quietSymbolTransition)
                }
            }
            .frame(width: 20, height: 20)
            .animation(
                completionSymbolAnimation(celebratesCompletion: celebratesCompletion),
                value: isComplete
            )

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .id(message)
                .transition(.opacity)

            Spacer()
        }
        .padding(.horizontal, 6)
    }

    private func gentleFooterMessage(
        for date: Date,
        schedule: PrayerSchedule?,
        currentDate: Date
    ) -> String {
        let completedCount = metrics.completedCount(on: date)

        if metrics.isPaused(on: date) {
            return "Take care of yourself. Your salah journey will be here when you return."
        }

        if let prayer = mostRecentMissedPrayer(
            on: date,
            schedule: schedule,
            currentDate: currentDate
        ) {
            return prayer.missedReflection.body
        }

        switch completedCount {
        case 5:
            return "Alhamdulillah — all five prayers recorded."
        case 4:
            return "One prayer left. May Allah make it easy."
        case 3:
            return "Three prayers recorded. Keep going, one salah at a time."
        case 2:
            return "Two prayers recorded. The next salah is another chance."
        case 1:
            return "Alhamdulillah for this one. Keep the next prayer close."
        default:
            if dayOffset < 0 {
                return "Nothing recorded for this day. You can still update it."
            }
            if metrics.currentStreak > 0 {
                return "Bismillah. Continue with the next prayer."
            }
            return "Every salah is a fresh chance to return to Allah."
        }
    }

    private func mostRecentMissedPrayer(
        on date: Date,
        schedule: PrayerSchedule?,
        currentDate: Date
    ) -> Prayer? {
        guard let schedule else { return nil }

        return Prayer.allCases.last { prayer in
            schedule.hasEnded(prayer, at: currentDate)
                && metrics.record(for: prayer, on: date) == nil
        }
    }

    private var sparkleTransition: AnyTransition {
        let insertion = AnyTransition.opacity
            .combined(with: .scale(scale: reduceMotion ? 0.98 : 0.94))
            .animation(.easeOut(duration: reduceMotion ? 0.16 : 0.2))
        let removal = AnyTransition.opacity
            .animation(.easeOut(duration: 0.14))

        return .asymmetric(insertion: insertion, removal: removal)
    }

    private var quietSymbolTransition: AnyTransition {
        .opacity.animation(.easeOut(duration: 0.14))
    }

    private func completionSymbolAnimation(celebratesCompletion: Bool) -> Animation {
        .easeOut(duration: celebratesCompletion ? (reduceMotion ? 0.16 : 0.2) : 0.14)
    }

    private func shouldCelebrateCompletion(on date: Date) -> Bool {
        guard let completionCelebrationDay else { return false }
        return Calendar.autoupdatingCurrent.isDate(completionCelebrationDay, inSameDayAs: date)
    }

    private func toggle(_ prayer: Prayer, on date: Date) {
        let existingRecord = metrics.record(for: prayer, on: date)
        let willCompleteDay = existingRecord == nil && metrics.completedCount(on: date) == Prayer.allCases.count - 1

        completionCelebrationDay = willCompleteDay ? date : nil
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

        synchronizeSalahFocus(
            prayer: prayer,
            on: date,
            isCompleted: existingRecord == nil
        )

        if existingRecord != nil {
            HapticFeedback.impact(.soft, intensity: 0.7)
        } else if willCompleteDay {
            HapticFeedback.notification(.success)
        } else {
            HapticFeedback.impact(.medium)
        }
    }

    private func setStatus(_ status: PrayerStatus, for prayer: Prayer, on date: Date) {
        let willCompleteDay = metrics.record(for: prayer, on: date) == nil
            && metrics.completedCount(on: date) == Prayer.allCases.count - 1
        completionCelebrationDay = willCompleteDay ? date : nil

        if let record = metrics.record(for: prayer, on: date) {
            record.status = status
            record.recordedAt = .now
        } else {
            modelContext.insert(PrayerRecord(day: date, prayer: prayer, status: status))
        }
        if save() {
            synchronizeSalahFocus(prayer: prayer, on: date, isCompleted: true)
            HapticFeedback.selection()
        } else {
            HapticFeedback.notification(.error)
        }
    }

    private func setAttendance(_ attendance: PrayerAttendance, for prayer: Prayer, on date: Date) {
        let willCompleteDay = metrics.record(for: prayer, on: date) == nil
            && metrics.completedCount(on: date) == Prayer.allCases.count - 1
        completionCelebrationDay = willCompleteDay ? date : nil

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
            synchronizeSalahFocus(prayer: prayer, on: date, isCompleted: true)
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

    private func synchronizeSalahFocus(
        prayer: Prayer,
        on date: Date,
        isCompleted: Bool
    ) {
        let identifier = PrayerRecord.identifier(for: date, prayer: prayer)
        let wasActiveRequirement = salahFocusService.activePrayerName == prayer.name
        salahFocusService.synchronize(
            coordinate: locationProvider.coordinate,
            records: records,
            pauses: pauses,
            periodMode: periodMode,
            calculationMethod: calculationMethod,
            asrMethod: asrMethod,
            completionOverride: (identifier, isCompleted)
        )

        if isCompleted,
           wasActiveRequirement,
           salahFocusService.activePrayerName == nil {
            showFocusReleaseConfirmation(for: prayer)
        }
    }

    private func showFocusReleaseConfirmation(for prayer: Prayer) {
        focusReleaseConfirmationTask?.cancel()
        withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.18)) {
            focusReleaseConfirmationPrayer = prayer
        }

        focusReleaseConfirmationTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.18)) {
                focusReleaseConfirmationPrayer = nil
            }
        }
    }

    private var sharingSyncKey: String {
        let date = selectedDate()
        let completionFingerprint = Prayer.allCases.map {
            metrics.record(for: $0, on: date) == nil ? "0" : "1"
        }.joined()
        return "\(dayOffset)-\(completionFingerprint)-\(sharingService.profile?.id ?? "local")"
    }

    private func selectedDate() -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
    }

    private func synchronizeSharing(at date: Date) async {
        let completedPrayers = Set(
            Prayer.allCases.filter { metrics.record(for: $0, on: date) != nil }
        )
        await sharingService.synchronizeDay(
            on: date,
            completedPrayers: completedPrayers
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
