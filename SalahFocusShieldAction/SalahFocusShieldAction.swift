import DeviceActivity
import Foundation
import ManagedSettings

final class SalahFocusShieldAction: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            if #available(iOS 26.5, *) {
                return .openParentalControlsApp
            }
            return .close

        case .secondaryButtonPressed:
            return beginTemporaryUnlock() ? .none : .close

        @unknown default:
            return .close
        }
    }

    private func beginTemporaryUnlock(now: Date = .now) -> Bool {
        var state = SalahFocusSharedStorage.load()
        guard
            state.isEnabled,
            let requirement = state.activeRequirement,
            !state.completedRecordIdentifiers.contains(requirement.recordIdentifier),
            !state.pausedDayIdentifiers.contains(requirement.dayIdentifier)
        else {
            SalahFocusShieldStore.clear()
            return true
        }

        let unlockUntil = now.addingTimeInterval(SalahFocusConstants.temporaryUnlockDuration)
        let activityCenter = DeviceActivityCenter()

        do {
            try activityCenter.startMonitoring(
                DeviceActivityName(SalahFocusConstants.temporaryUnlockActivity),
                during: temporaryUnlockSchedule(endingAt: unlockUntil)
            )
            state.temporaryUnlockUntil = unlockUntil
            try SalahFocusSharedStorage.save(state)
            SalahFocusShieldStore.clear()
            return true
        } catch {
            activityCenter.stopMonitoring([
                DeviceActivityName(SalahFocusConstants.temporaryUnlockActivity)
            ])
            return false
        }
    }

    private func temporaryUnlockSchedule(endingAt date: Date) -> DeviceActivitySchedule {
        let calendar = Calendar.autoupdatingCurrent
        let components: Set<Calendar.Component> = [
            .year, .month, .day, .hour, .minute, .second
        ]
        let intervalEnd = calendar.date(
            byAdding: .day,
            value: SalahFocusConstants.monitoringWindowDayCount,
            to: date
        ) ?? date

        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: date),
            intervalEnd: calendar.dateComponents(components, from: intervalEnd),
            repeats: false
        )
    }
}
