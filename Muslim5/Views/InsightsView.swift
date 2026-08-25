import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query private var records: [PrayerRecord]
    @Query private var pauses: [TrackingPause]

    private var metrics: ProgressMetrics { ProgressMetrics(records: records, pauses: pauses) }

    var body: some View {
        VStack(spacing: 18) {
            consistencyCard
            prayerBreakdown
        }
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your last 30 days")
                        .font(.headline)
                    Text(consistencyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: reflectionSymbol)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }

            Text(monthRhythmTitle)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            ProgressView(value: metrics.last30DayConsistency)
                .tint(AppTheme.accent)
                .scaleEffect(x: 1, y: 1.6)

            Text("You recorded \(metrics.last30DayConsistency, format: .percent.precision(.fractionLength(0))) of your prayers")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var prayerBreakdown: some View {
        VStack(alignment: .leading, spacing: 18) {
                Text("Prayer by prayer")
                    .font(.headline)

            ForEach(Prayer.allCases) { prayer in
                let count = recentCount(for: prayer)
                HStack(spacing: 12) {
                    Image(systemName: prayer.symbol)
                        .foregroundStyle(AppTheme.prayerColor(for: prayer))
                        .frame(width: 24)
                    Text(prayer.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(rhythmLabel(for: count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(count == 0 ? Color.secondary : AppTheme.success)
                }
            }

            if let strongest = strongestRecentPrayer {
                Divider()
                Label("\(strongest.name) has been your most consistent prayer lately.", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding(22)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var consistencyMessage: String {
        switch metrics.last30DayConsistency {
        case 0: "Bismillah. Start by recording your next prayer."
        case 0..<0.4: "Every prayer you record is a step forward."
        case 0.4..<0.8: "Your consistency is growing, one salah at a time."
        default: "MashaAllah, you’ve been consistent with your salah."
        }
    }

    private var monthRhythmTitle: String {
        switch metrics.last30DayConsistency {
        case 0: "Ready when you are"
        case 0..<0.4: "A start, Alhamdulillah"
        case 0.4..<0.8: "Growing steadily"
        default: "Steady, MashaAllah"
        }
    }

    private var reflectionSymbol: String {
        switch metrics.last30DayConsistency {
        case 0: "sunrise.fill"
        case 0..<0.4: "leaf.fill"
        case 0.4..<0.8: "heart.fill"
        default: "sparkles"
        }
    }

    private func recentCount(for prayer: Prayer) -> Int {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)) ?? .distantPast
        return records.filter { $0.prayer == prayer && $0.day >= start }.count
    }

    private func rhythmLabel(for count: Int) -> String {
        switch count {
        case 0: "Not recorded yet"
        case 1..<10: "A few times"
        case 10..<22: "Often"
        default: "Consistent"
        }
    }

    private var strongestRecentPrayer: Prayer? {
        let counts = Prayer.allCases.map { prayer in (prayer, recentCount(for: prayer)) }
        guard let strongest = counts.max(by: { $0.1 < $1.1 }), strongest.1 > 0 else { return nil }
        return strongest.0
    }
}
