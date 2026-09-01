import DeviceActivity
import Foundation

final class SalahFocusMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        var state = SalahFocusSharedStorage.load()

        if activity.rawValue == SalahFocusConstants.temporaryUnlockActivity {
            finishTemporaryUnlock(state: &state, activity: activity)
            return
        }

        guard
            state.isEnabled,
            let requirement = state.scheduledRequirement,
            !state.completedRecordIdentifiers.contains(requirement.recordIdentifier),
            !state.pausedDayIdentifiers.contains(requirement.dayIdentifier),
            activity.rawValue == expectedActivityName(requirement: requirement, revision: state.revision)
        else {
            SalahFocusShieldStore.clear()
            return
        }

        state.activeRequirement = requirement
        state.scheduledRequirement = nil

        do {
            try SalahFocusSharedStorage.save(state)
            SalahFocusShieldStore.apply()
        } catch {
            SalahFocusShieldStore.clear()
        }
    }

    private func finishTemporaryUnlock(
        state: inout SalahFocusSharedState,
        activity: DeviceActivityName,
        now: Date = .now
    ) {
        guard let unlockUntil = state.temporaryUnlockUntil else {
            DeviceActivityCenter().stopMonitoring([activity])
            return
        }

        guard unlockUntil <= now else {
            SalahFocusShieldStore.clear()
            rescheduleTemporaryUnlock(activity: activity, endingAt: unlockUntil)
            return
        }

        state.temporaryUnlockUntil = nil

        guard
            state.isEnabled,
            let requirement = state.activeRequirement,
            !state.completedRecordIdentifiers.contains(requirement.recordIdentifier),
            !state.pausedDayIdentifiers.contains(requirement.dayIdentifier)
        else {
            try? SalahFocusSharedStorage.save(state)
            SalahFocusShieldStore.clear()
            return
        }

        do {
            try SalahFocusSharedStorage.save(state)
            SalahFocusShieldStore.apply()
        } catch {
            SalahFocusShieldStore.clear()
        }
    }

    private func rescheduleTemporaryUnlock(
        activity: DeviceActivityName,
        endingAt unlockUntil: Date
    ) {
        let calendar = Calendar.autoupdatingCurrent
        let components: Set<Calendar.Component> = [
            .year, .month, .day, .hour, .minute, .second
        ]
        guard let intervalEnd = calendar.date(
            byAdding: .minute,
            value: 15,
            to: unlockUntil
        ) else {
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: unlockUntil),
            intervalEnd: calendar.dateComponents(components, from: intervalEnd),
            repeats: false
        )
        try? DeviceActivityCenter().startMonitoring(activity, during: schedule)
    }

    private func expectedActivityName(
        requirement: SalahFocusRequirement,
        revision: Int
    ) -> String {
        "\(SalahFocusConstants.activityPrefix).\(revision).\(requirement.dayIdentifier).\(requirement.prayerRawValue)"
    }
}
