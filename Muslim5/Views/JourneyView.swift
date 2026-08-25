import SwiftData
import SwiftUI

struct JourneyView: View {
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]

    private let calendar = Calendar.current
    private var metrics: ProgressMetrics { ProgressMetrics(records: records, pauses: pauses) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summary
                    contributionCard
                    legend
                    InsightsView()
                    reflectionCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your journey")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile(value: "\(metrics.currentStreak)", label: "days in rhythm", symbol: "flame.fill", color: AppTheme.gold)
            summaryTile(value: "\(metrics.perfectDays)", label: "full prayer days", symbol: "sparkles", color: AppTheme.success)
        }
    }

    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("A season of returning")
                    .font(.headline)
                Text("Every square holds one day from your journey.")
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
                Text(index == 1 ? "M" : index == 3 ? "W" : index == 5 ? "F" : "")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 15)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Started")
            ForEach(0...5, id: \.self) { count in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.contributionColor(for: count))
                    .frame(width: 14, height: 14)
            }
            Text("All five")
            Spacer()
            Circle()
                .stroke(AppTheme.accent, lineWidth: 1.5)
                .frame(width: 13, height: 13)
            Text("Rested")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private var reflectionCard: some View {
        let reflection = journeyReflection

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

    private var journeyReflection: (title: String, body: String) {
        if metrics.isPaused(on: .now) {
            return (
                "Rest without losing your place",
                "This pause is part of your journey, not a step away from it."
            )
        }

        if records.isEmpty {
            return (
                "Your journey begins here",
                "One prayer is enough to place the first mark on your path."
            )
        }

        if metrics.currentStreak >= 30 {
            return (
                "A month held with care",
                "Thirty days of returning have become something steady and deeply rooted."
            )
        }

        if metrics.currentStreak >= 7 {
            return (
                "A rhythm is taking root",
                "A full week of faithful days shows what gentle consistency can become."
            )
        }

        if metrics.currentStreak >= 3 {
            return (
                "Keep the rhythm close",
                "These steady days are becoming a pattern you can return to."
            )
        }

        if metrics.last30DayConsistency >= 0.9 {
            return (
                "Quiet consistency, clearly seen",
                "Your recent days show a strong rhythm, built one prayer at a time."
            )
        }

        if metrics.perfectDays >= 10 {
            return (
                "You have returned many times",
                "Every full prayer day is evidence of care, even when the path between them varies."
            )
        }

        if metrics.last30DayConsistency >= 0.6 {
            return (
                "Steadiness grows gradually",
                "Your recent pattern already holds momentum. Let the next prayer carry it forward."
            )
        }

        if metrics.perfectDays > 0 {
            return (
                "You know the way back",
                "You have completed a full day before. That path is still open to you."
            )
        }

        if let prayer = metrics.strongestPrayer {
            return (
                "A strength is already forming",
                "\(prayer.name) has been your steadiest moment. Let that strength support the others."
            )
        }

        return (
            "Your story keeps going",
            "A quiet day never erases the days before it. The next prayer is always a new beginning."
        )
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
            .accessibilityValue(paused ? "Tracking paused" : "\(count) of 5 prayers")
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
