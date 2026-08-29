import Foundation
import SwiftData

enum ICloudSyncDataNormalizer {
    @discardableResult
    static func normalize(
        records: [PrayerRecord],
        pauses: [TrackingPause],
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Bool {
        let normalizedRecords = normalizePrayerRecords(records, in: context)
        let normalizedPauses = normalizeTrackingPauses(pauses, in: context, calendar: calendar)
        return normalizedRecords || normalizedPauses
    }

    private static func normalizePrayerRecords(
        _ records: [PrayerRecord],
        in context: ModelContext
    ) -> Bool {
        var changed = false

        for duplicates in Dictionary(grouping: records, by: \PrayerRecord.id).values where duplicates.count > 1 {
            let sorted = duplicates.sorted(by: prayerRecordComesBefore)
            guard let winner = sorted.first else { continue }

            if winner.attendanceRawValue == nil,
               let attended = sorted.first(where: { $0.attendanceRawValue != nil }) {
                winner.attendanceRawValue = attended.attendanceRawValue
                changed = true
            }

            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }

    private static func prayerRecordComesBefore(_ lhs: PrayerRecord, _ rhs: PrayerRecord) -> Bool {
        if lhs.recordedAt != rhs.recordedAt {
            return lhs.recordedAt > rhs.recordedAt
        }

        let lhsTieBreak = "\(lhs.statusRawValue)|\(lhs.attendanceRawValue ?? "")|\(lhs.prayerRawValue)"
        let rhsTieBreak = "\(rhs.statusRawValue)|\(rhs.attendanceRawValue ?? "")|\(rhs.prayerRawValue)"
        return lhsTieBreak < rhsTieBreak
    }

    private static func normalizeTrackingPauses(
        _ pauses: [TrackingPause],
        in context: ModelContext,
        calendar: Calendar
    ) -> Bool {
        var changed = false
        let groups = Dictionary(grouping: pauses, by: \TrackingPause.reason)

        for reasonPauses in groups.values {
            let sorted = reasonPauses.sorted {
                if $0.startDay != $1.startDay { return $0.startDay < $1.startDay }
                return $0.id.uuidString < $1.id.uuidString
            }
            guard var current = sorted.first else { continue }

            for candidate in sorted.dropFirst() {
                let currentEnd = current.endDay.map { calendar.startOfDay(for: $0) } ?? .distantFuture
                let candidateStart = calendar.startOfDay(for: candidate.startDay)

                guard candidateStart <= currentEnd else {
                    current = candidate
                    continue
                }

                let mergedEnd: Date?
                if current.endDay == nil || candidate.endDay == nil {
                    mergedEnd = nil
                } else {
                    mergedEnd = max(current.endDay!, candidate.endDay!)
                }

                if current.endDay != mergedEnd {
                    current.endDay = mergedEnd
                    changed = true
                }
                context.delete(candidate)
                changed = true
            }
        }
        return changed
    }
}
