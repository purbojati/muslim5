import DeviceActivity
import Foundation

final class SalahFocusMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        var state = SalahFocusSharedStorage.load()

        if activity.rawValue == SalahFocusConstants.temporaryUnlockActivity {
            finishTemporaryUnlock(state: &state)
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

    private func finishTemporaryUnlock(state: inout SalahFocusSharedState) {
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

    private func expectedActivityName(
        requirement: SalahFocusRequirement,
        revision: Int
    ) -> String {
        "\(SalahFocusConstants.activityPrefix).\(revision).\(requirement.dayIdentifier).\(requirement.prayerRawValue)"
    }
}
