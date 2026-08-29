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

    private func decision(
        isEnabled: Bool = true,
        activeRequirement: SalahFocusRequirement? = nil,
        occurrences: [SalahFocusRequirement],
        completed: Set<String> = [],
        pausedDays: Set<String> = []
    ) -> SalahFocusDecision {
        SalahFocusDecision.resolve(
            isEnabled: isEnabled,
            enabledAt: enabledAt,
            activeRequirement: activeRequirement,
            occurrences: occurrences,
            completedRecordIdentifiers: completed,
            pausedDayIdentifiers: pausedDays,
            now: now
        )
    }
}
