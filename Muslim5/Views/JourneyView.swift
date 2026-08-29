import SwiftData
import SwiftUI

struct JourneyView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var locationProvider: LocationProvider
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"

    private let calendar = Calendar.current
    private let prayerScheduleService = PrayerScheduleService()
    private var metrics: ProgressMetrics { ProgressMetrics(records: records, pauses: pauses) }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summary
                        contributionCard
                        legend
                        InsightsView()
                        reflectionCard(at: timeline.date)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Your salah journey")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile(
                value: "\(metrics.currentStreak)",
                label: String(localized: "current streak"),
                symbol: "flame.fill",
                color: AppTheme.gold
            )
            summaryTile(
                value: "\(metrics.perfectDays)",
                label: String(localized: "days with all five"),
                symbol: "sparkles",
                color: AppTheme.success
            )
        }
    }

    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your days in salah")
                    .font(.headline)
                Text("Each square shows how many prayers you recorded that day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 7) {
                    weekdayLabels

                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(15), spacing: 5), count: 7), spacing: 5) {
                        ForEach(gridDates, id: \.self) { date in
                            dayCell(for: date)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.trailing)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var weekdayLabels: some View {
        VStack(spacing: 5) {
            ForEach(0..<7) { index in
                Text(weekdayLabel(at: index))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 15)
            }
        }
    }

    private func weekdayLabel(at index: Int) -> String {
        guard [1, 3, 5].contains(index) else { return "" }
        var localizedCalendar = calendar
        localizedCalendar.locale = locale
        let symbols = localizedCalendar.veryShortWeekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("1 prayer")
            ForEach(0...5, id: \.self) { count in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.contributionColor(for: count))
                    .frame(width: 14, height: 14)
            }
            Text("All 5")
            Spacer()
            Circle()
                .stroke(AppTheme.accent, lineWidth: 1.5)
                .frame(width: 13, height: 13)
            Text("Paused")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private func reflectionCard(at date: Date) -> some View {
        let reflection = journeyReflection(at: date)

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 5) {
                Text(reflection.title)
                    .font(.headline)
                Text(reflection.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func journeyReflection(at date: Date) -> (title: String, body: String) {
        if metrics.isPaused(on: date) {
            return (
                String(localized: "Your pause is protected"),
                String(localized: "Period Mode keeps these days from affecting your streak. Take care of yourself.")
            )
        }

        if let prayer = mostRecentMissedPrayer(at: date) {
            return prayer.missedReflection
        }

        if records.isEmpty {
            return (
                String(localized: "Bismillah, begin with one"),
                String(localized: "Record your next salah after you pray. Your journey can start there.")
            )
        }

        if metrics.currentStreak >= 30 {
            return (
                String(localized: "MashaAllah — 30 days"),
                String(localized: "May Allah keep you steadfast and make salah beloved to your heart.")
            )
        }

        if metrics.currentStreak >= 7 {
            return (
                String(localized: "MashaAllah — one full week"),
                String(localized: "Seven days of showing up for salah. Keep asking Allah for steadfastness.")
            )
        }

        if metrics.currentStreak >= 3 {
            return (
                String(localized: "A good start, Alhamdulillah"),
                String(localized: "You’re building consistency day by day. Keep the next salah close.")
            )
        }

        if metrics.last30DayConsistency >= 0.9 {
            return (
                String(localized: "MashaAllah, you’ve been consistent"),
                String(localized: "Your last 30 days show real care for salah. May Allah help you continue.")
            )
        }

        if metrics.perfectDays >= 10 {
            return (
                String(localized: "Ten complete days and counting"),
                String(localized: "You’ve recorded all five prayers on many days. That effort still matters.")
            )
        }

        if metrics.last30DayConsistency >= 0.6 {
            return (
                String(localized: "Consistency grows one salah at a time"),
                String(localized: "You’ve built a good foundation. Let the next prayer carry you forward.")
            )
        }

        if metrics.perfectDays > 0 {
            return (
                String(localized: "You’ve done all five before"),
                String(localized: "That means you can do it again, inshaAllah. Begin with the next prayer.")
            )
        }

        if let prayer = metrics.strongestPrayer {
            return (
                String(localized: "\(prayer.name) is your strongest prayer"),
                String(localized: "Alhamdulillah for that consistency. Let it help you strengthen the other prayers too.")
            )
        }

        return (
            String(localized: "The door is always open"),
            String(localized: "A missed day doesn’t erase your effort. Begin again with the next salah.")
        )
    }

    private func mostRecentMissedPrayer(at date: Date) -> Prayer? {
        guard
            let coordinate = locationProvider.coordinate,
            let schedule = prayerScheduleService.schedule(
                for: coordinate,
                at: date,
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
            )
        else {
            return nil
        }

        return Prayer.allCases.last { prayer in
            schedule.hasEnded(prayer, at: date)
                && metrics.record(for: prayer, on: date) == nil
        }
    }

    private func summaryTile(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isFuture = date > calendar.startOfDay(for: .now)
        let paused = metrics.isPaused(on: date)
        let count = metrics.completedCount(on: date)

        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isFuture ? Color.clear : AppTheme.contributionColor(for: count))
            .overlay {
                if paused && !isFuture {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(AppTheme.accent, lineWidth: 1.5)
                }
            }
            .frame(width: 15, height: 15)
            .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(
                paused
                    ? String(localized: "Tracking paused")
                    : String(localized: "\(count) of 5 prayers")
            )
    }

    private var gridDates: [Date] {
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceSunday = weekday - calendar.firstWeekday
        let normalizedOffset = daysSinceSunday >= 0 ? daysSinceSunday : daysSinceSunday + 7
        let endOfWeek = calendar.date(byAdding: .day, value: 6 - normalizedOffset, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -(20 * 7 - 1), to: endOfWeek) ?? today
        return (0..<(20 * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
