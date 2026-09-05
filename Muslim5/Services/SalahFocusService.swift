import Combine
import CoreLocation
import DeviceActivity
@preconcurrency import FamilyControls
import Foundation

struct SalahFocusOccurrence: Equatable {
    let prayer: Prayer
    let day: Date
    let start: Date

    func requirement(calendar: Calendar) -> SalahFocusRequirement {
        SalahFocusRequirement(
            prayerRawValue: prayer.rawValue,
            dayIdentifier: Self.dayIdentifier(for: day, calendar: calendar),
            start: start
        )
    }

    static func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

enum SalahFocusDecision: Equatable {
    case clear
    case shield(SalahFocusRequirement)
    case temporaryUnlock(SalahFocusRequirement, until: Date)
    case schedule(SalahFocusRequirement)

    static func resolve(
        state: SalahFocusSharedState,
        occurrences: [SalahFocusRequirement],
        now: Date
    ) -> SalahFocusDecision {
        resolve(
            isEnabled: state.isEnabled,
            enabledAt: state.enabledAt,
            activeRequirement: state.activeRequirement,
            temporaryUnlockUntil: state.temporaryUnlockUntil,
            occurrences: occurrences,
            completedRecordIdentifiers: state.completedRecordIdentifiers,
            pausedDayIdentifiers: state.pausedDayIdentifiers,
            now: now
        )
    }

    static func resolve(
        isEnabled: Bool,
        enabledAt: Date?,
        activeRequirement: SalahFocusRequirement?,
        temporaryUnlockUntil: Date? = nil,
        occurrences: [SalahFocusRequirement],
        completedRecordIdentifiers: Set<String>,
        pausedDayIdentifiers: Set<String>,
        now: Date
    ) -> SalahFocusDecision {
        guard isEnabled, let enabledAt else {
            return .clear
        }

        let applicable = occurrences
            .filter { $0.start >= enabledAt }
            .filter { !pausedDayIdentifiers.contains($0.dayIdentifier) }
            .sorted { $0.start < $1.start }

        if let latestDue = applicable.last(where: { $0.start <= now }),
           !completedRecordIdentifiers.contains(latestDue.recordIdentifier) {
            if activeRequirement == latestDue,
               let temporaryUnlockUntil,
               temporaryUnlockUntil > now {
                return .temporaryUnlock(latestDue, until: temporaryUnlockUntil)
            }
            return .shield(latestDue)
        }

        if let future = applicable.first(where: {
            $0.start > now && !completedRecordIdentifiers.contains($0.recordIdentifier)
        }) {
            return .schedule(future)
        }

        return .clear
    }
}

@MainActor
final class SalahFocusService: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var authorizationStatus: FamilyControls.AuthorizationStatus
    @Published private(set) var activePrayerName: String?
    @Published private(set) var lastError: String?
    @Published private(set) var configurationRevision = 0

    private let authorizationCenter = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    private let scheduleService = PrayerScheduleService()
    private var state: SalahFocusSharedState

    init() {
        let stored = SalahFocusSharedStorage.load()
        state = stored
        isEnabled = stored.isEnabled
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        activePrayerName = stored.activeRequirement?.prayerName
    }

    var isAuthorized: Bool {
        if #available(iOS 26.4, *) {
            authorizationStatus == .approved || authorizationStatus == .approvedWithDataAccess
        } else {
            authorizationStatus == .approved
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = authorizationCenter.authorizationStatus
        if authorizationStatus == .denied, state.isEnabled {
            disable(clearError: true)
            lastError = String(localized: "Screen Time access is no longer available. Set up Salah Focus again.")
        }
    }

    func prepareForLaunch() async {
        refreshAuthorizationStatus()
        guard state.isEnabled, authorizationStatus == .notDetermined else { return }

        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
        } catch {
            authorizationStatus = authorizationCenter.authorizationStatus
            stopMuslim5Monitoring()
            SalahFocusShieldStore.clear()
            lastError = error.localizedDescription
        }
    }

    func requestAuthorization() async -> Bool {
        lastError = nil
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            return isAuthorized
        } catch {
            refreshAuthorizationStatus()
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func enable(now: Date = .now) -> Bool {
        refreshAuthorizationStatus()
        guard isAuthorized else {
            lastError = String(localized: "Allow Screen Time access before turning on Salah Focus.")
            return false
        }
        state.isEnabled = true
        state.enabledAt = now
        state.activeRequirement = nil
        state.scheduledRequirement = nil
        state.temporaryUnlockUntil = nil
        state.revision += 1
        isEnabled = true
        lastError = nil
        persistState()
        configurationRevision += 1
        return true
    }

    func disable() {
        disable(clearError: true)
    }

    func setPeriodMode(_ enabled: Bool) {
        if enabled {
            state.activeRequirement = nil
            state.scheduledRequirement = nil
            state.temporaryUnlockUntil = nil
            state.revision += 1
            activePrayerName = nil
            persistState()
            stopMuslim5Monitoring()
            SalahFocusShieldStore.clear()
        }
        configurationRevision += 1
    }

    func synchronize(
        coordinate: CLLocationCoordinate2D?,
        records: [PrayerRecord],
        pauses: [TrackingPause],
        periodMode: Bool,
        calculationMethod: String,
        asrMethod: String,
        completionOverride: (identifier: String, isCompleted: Bool)? = nil,
        now: Date = .now,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        reloadSharedState()
        refreshAuthorizationStatus()
        state.selection = FamilyActivitySelection()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        state.completedRecordIdentifiers = Set(records.map(\.id))
        if let completionOverride {
            if completionOverride.isCompleted {
                state.completedRecordIdentifiers.insert(completionOverride.identifier)
            } else {
                state.completedRecordIdentifiers.remove(completionOverride.identifier)
            }
        }
        state.pausedDayIdentifiers = pausedDayIdentifiers(
            pauses: pauses,
            around: now,
            calendar: calendar
        )

        guard state.isEnabled, isAuthorized, !periodMode else {
            state.activeRequirement = nil
            state.scheduledRequirement = nil
            state.temporaryUnlockUntil = nil
            activePrayerName = nil
            persistState()
            stopMuslim5Monitoring()
            SalahFocusShieldStore.clear()
            return
        }

        guard let coordinate,
              let schedule = scheduleService.schedule(
                for: coordinate,
                at: now,
                timeZone: timeZone,
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
              ) else {
            state.activeRequirement = nil
            state.scheduledRequirement = nil
            state.temporaryUnlockUntil = nil
            activePrayerName = nil
            lastError = String(localized: "Salah Focus needs a valid location and prayer schedule.")
            persistState()
            stopMuslim5Monitoring()
            SalahFocusShieldStore.clear()
            return
        }

        let requirements = scheduleService
            .focusOccurrences(from: schedule, calendar: calendar)
            .map { $0.requirement(calendar: calendar) }

        lastError = nil
        switch SalahFocusDecision.resolve(state: state, occurrences: requirements, now: now) {
        case .clear:
            state.activeRequirement = nil
            state.scheduledRequirement = nil
            state.temporaryUnlockUntil = nil
            activePrayerName = nil
            persistState()
            stopMuslim5Monitoring()
            SalahFocusShieldStore.clear()

        case .shield(let requirement):
            state.activeRequirement = requirement
            state.scheduledRequirement = nil
            state.temporaryUnlockUntil = nil
            activePrayerName = requirement.prayerName
            persistState()
            stopMuslim5Monitoring()
            SalahFocusShieldStore.apply()

        case .temporaryUnlock(let requirement, let unlockUntil):
            state.activeRequirement = requirement
            state.scheduledRequirement = nil
            activePrayerName = requirement.prayerName
            persistState()
            SalahFocusShieldStore.clear()

            if !ensureTemporaryUnlockMonitoring(
                endingAt: unlockUntil,
                now: now,
                calendar: calendar
            ) {
                state.temporaryUnlockUntil = nil
                SalahFocusShieldStore.apply()
            }

        case .schedule(let requirement):
            state.activeRequirement = nil
            state.temporaryUnlockUntil = nil
            activePrayerName = nil
            scheduleMonitoring(requirement, calendar: calendar)
            SalahFocusShieldStore.clear()
        }

        persistState()
    }

    private func reloadSharedState() {
        state = SalahFocusSharedStorage.load()
        isEnabled = state.isEnabled
        activePrayerName = state.activeRequirement?.prayerName
    }

    private func disable(clearError: Bool) {
        state.isEnabled = false
        state.enabledAt = nil
        state.activeRequirement = nil
        state.scheduledRequirement = nil
        state.temporaryUnlockUntil = nil
        state.revision += 1
        isEnabled = false
        activePrayerName = nil
        if clearError { lastError = nil }
        persistState()
        stopMuslim5Monitoring()
        SalahFocusShieldStore.clear()
        configurationRevision += 1
    }

    private func scheduleMonitoring(_ requirement: SalahFocusRequirement, calendar: Calendar) {
        if state.scheduledRequirement == requirement,
           activityCenter.activities.contains(activityName(for: requirement, revision: state.revision)) {
            return
        }

        state.revision += 1
        state.scheduledRequirement = requirement
        persistState()
        stopMuslim5Monitoring()

        guard let intervalEnd = calendar.date(
            byAdding: .day,
            value: SalahFocusConstants.monitoringWindowDayCount,
            to: requirement.start
        ) else {
            state.scheduledRequirement = nil
            lastError = String(localized: "Unable to create the next Salah Focus schedule.")
            persistState()
            return
        }

        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: requirement.start),
            intervalEnd: calendar.dateComponents(components, from: intervalEnd),
            repeats: false
        )

        do {
            try activityCenter.startMonitoring(
                activityName(for: requirement, revision: state.revision),
                during: schedule
            )
        } catch {
            state.scheduledRequirement = nil
            lastError = error.localizedDescription
            persistState()
        }
    }

    private func ensureTemporaryUnlockMonitoring(
        endingAt unlockUntil: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let activity = DeviceActivityName(SalahFocusConstants.temporaryUnlockActivity)
        if activityCenter.activities.contains(activity) {
            return true
        }
        guard
            unlockUntil > now,
            let intervalEnd = calendar.date(
                byAdding: .day,
                value: SalahFocusConstants.monitoringWindowDayCount,
                to: unlockUntil
            )
        else {
            return false
        }

        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: unlockUntil),
            intervalEnd: calendar.dateComponents(components, from: intervalEnd),
            repeats: false
        )

        do {
            try activityCenter.startMonitoring(activity, during: schedule)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func activityName(
        for requirement: SalahFocusRequirement,
        revision: Int
    ) -> DeviceActivityName {
        DeviceActivityName(SalahFocusConstants.activityName(for: requirement, revision: revision))
    }

    private func stopMuslim5Monitoring() {
        let activities = activityCenter.activities.filter {
            $0.rawValue.hasPrefix(SalahFocusConstants.activityPrefix)
        }
        guard !activities.isEmpty else { return }
        activityCenter.stopMonitoring(activities)
    }

    private func pausedDayIdentifiers(
        pauses: [TrackingPause],
        around date: Date,
        calendar: Calendar
    ) -> Set<String> {
        (-2...2).reduce(into: Set<String>()) { result, offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { return }
            if pauses.contains(where: { $0.includes(day, calendar: calendar) }) {
                result.insert(SalahFocusOccurrence.dayIdentifier(for: day, calendar: calendar))
            }
        }
    }

    private func persistState() {
        do {
            try SalahFocusSharedStorage.save(state)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
