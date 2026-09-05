import XCTest
@testable import Muslim_5

final class SalahFocusDecisionTests: XCTestCase {
    private let enabledAt = Date(timeIntervalSince1970: 100)
    private let now = Date(timeIntervalSince1970: 300)

    func testDisabledStateAlwaysClears() {
        XCTAssertEqual(
            decision(isEnabled: false, occurrences: [fajr]),
            .clear
        )
    }

    func testUnfinishedActiveRequirementStaysShielded() {
        XCTAssertEqual(
            decision(activeRequirement: fajr, occurrences: [dhuhr]),
            .shield(fajr)
        )
    }

    func testActiveTemporaryUnlockStaysOpenUntilItsDeadline() {
        let unlockUntil = Date(timeIntervalSince1970: 2_100)

        XCTAssertEqual(
            decision(
                activeRequirement: fajr,
                temporaryUnlockUntil: unlockUntil,
                occurrences: [fajr, dhuhr]
            ),
            .temporaryUnlock(fajr, until: unlockUntil)
        )
    }

    func testExpiredTemporaryUnlockRestoresShield() {
        XCTAssertEqual(
            decision(
                activeRequirement: fajr,
                temporaryUnlockUntil: Date(timeIntervalSince1970: 299),
                occurrences: [fajr, dhuhr]
            ),
            .shield(fajr)
        )
    }

    func testCompletingActiveRequirementAdvancesToNextDuePrayer() {
        XCTAssertEqual(
            decision(
                activeRequirement: fajr,
                occurrences: [fajr, dhuhr],
                completed: [fajr.recordIdentifier]
            ),
            .shield(dhuhr)
        )
    }

    func testOccurrenceBeforeFeatureWasEnabledIsIgnored() {
        let oldPrayer = requirement("fajr", day: "1970-01-01", start: 90)
        XCTAssertEqual(
            decision(occurrences: [oldPrayer, futureIsha]),
            .schedule(futureIsha)
        )
    }

    func testPausedDayIsSkipped() {
        XCTAssertEqual(
            decision(
                occurrences: [fajr, futureIsha],
                pausedDays: [fajr.dayIdentifier]
            ),
            .schedule(futureIsha)
        )
    }

    func testNextFuturePrayerIsScheduled() {
        XCTAssertEqual(
            decision(occurrences: [futureIsha]),
            .schedule(futureIsha)
        )
    }

    func testCompletedOccurrencesClearWhenNothingRemains() {
        XCTAssertEqual(
            decision(occurrences: [fajr], completed: [fajr.recordIdentifier]),
            .clear
        )
    }

    func testRequirementIdentifierMatchesPrayerRecordIdentifier() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!
        let occurrence = SalahFocusOccurrence(prayer: .fajr, day: day, start: day)

        XCTAssertEqual(
            occurrence.requirement(calendar: calendar).recordIdentifier,
            PrayerRecord.identifier(for: day, prayer: .fajr, calendar: calendar)
        )
    }

    func testCurrentMonitorCallbackShieldsScheduledPrayer() {
        let state = enabledState(scheduledRequirement: fajr, revision: 4)

        XCTAssertEqual(
            SalahFocusMonitorStartDecision.resolve(
                activityName: SalahFocusConstants.activityName(for: fajr, revision: 4),
                state: state
            ),
            .shield(fajr)
        )
    }

    func testStaleMonitorCallbackDoesNotClearCurrentShield() {
        let state = enabledState(scheduledRequirement: dhuhr, revision: 5)

        XCTAssertEqual(
            SalahFocusMonitorStartDecision.resolve(
                activityName: SalahFocusConstants.activityName(for: fajr, revision: 4),
                state: state
            ),
            .ignore
        )
    }

    func testCompletedScheduledPrayerClearsWithoutShielding() {
        var state = enabledState(scheduledRequirement: fajr, revision: 4)
        state.completedRecordIdentifiers = [fajr.recordIdentifier]

        XCTAssertEqual(
            SalahFocusMonitorStartDecision.resolve(
                activityName: SalahFocusConstants.activityName(for: fajr, revision: 4),
                state: state
            ),
            .clear
        )
    }

    func testDisabledMonitorStateClearsLegacyShield() {
        var state = enabledState(scheduledRequirement: fajr, revision: 4)
        state.isEnabled = false

        XCTAssertEqual(
            SalahFocusMonitorStartDecision.resolve(
                activityName: SalahFocusConstants.activityName(for: fajr, revision: 4),
                state: state
            ),
            .clear
        )
    }

    private var fajr: SalahFocusRequirement {
        requirement("fajr", day: "1970-01-02", start: 200)
    }

    private var dhuhr: SalahFocusRequirement {
        requirement("dhuhr", day: "1970-01-02", start: 250)
    }

    private var futureIsha: SalahFocusRequirement {
        requirement("isha", day: "1970-01-03", start: 400)
    }

    private func requirement(
        _ prayer: String,
        day: String,
        start: TimeInterval
    ) -> SalahFocusRequirement {
        SalahFocusRequirement(
            prayerRawValue: prayer,
            dayIdentifier: day,
            start: Date(timeIntervalSince1970: start)
        )
    }

    private func enabledState(
        scheduledRequirement: SalahFocusRequirement,
        revision: Int
    ) -> SalahFocusSharedState {
        var state = SalahFocusSharedState()
        state.isEnabled = true
        state.enabledAt = enabledAt
        state.scheduledRequirement = scheduledRequirement
        state.revision = revision
        return state
    }

    private func decision(
        isEnabled: Bool = true,
        activeRequirement: SalahFocusRequirement? = nil,
        temporaryUnlockUntil: Date? = nil,
        occurrences: [SalahFocusRequirement],
        completed: Set<String> = [],
        pausedDays: Set<String> = []
    ) -> SalahFocusDecision {
        SalahFocusDecision.resolve(
            isEnabled: isEnabled,
            enabledAt: enabledAt,
            activeRequirement: activeRequirement,
            temporaryUnlockUntil: temporaryUnlockUntil,
            occurrences: occurrences,
            completedRecordIdentifiers: completed,
            pausedDayIdentifiers: pausedDays,
            now: now
        )
    }
}
