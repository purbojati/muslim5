import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
    @AppStorage("travelMode") private var travelMode = false

    private var metrics: ProgressMetrics { ProgressMetrics(records: records, pauses: pauses) }
    private var completedToday: Int { metrics.completedCount(on: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    welcomeHeader
                    dailyCompanionCard

                    if periodMode {
                        pauseBanner
                    } else if travelMode {
                        travelBanner
                    }

                    prayerList
                    gentleFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Assalamu alaikum")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyCompanionCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(completionTitle)
                        .font(.title2.bold())
                    Text(completionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("\(completedToday)/5")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                ForEach(Prayer.allCases) { prayer in
                    let isDone = metrics.record(for: prayer, on: .now) != nil
                    ZStack {
                        Circle()
                            .fill(isDone ? AppTheme.success : .white.opacity(0.12))
                        Image(systemName: isDone ? "checkmark" : prayer.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isDone ? .white : .white.opacity(0.6))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel("\(prayer.name) \(isDone ? "complete" : "incomplete")")
                }
            }

            Label(streakMessage, systemImage: metrics.currentStreak > 0 ? "flame.fill" : "sunrise.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppTheme.deepIndigo.opacity(0.18), radius: 18, y: 10)
    }

    private var prayerList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your five moments")
                    .font(.title3.bold())
                Text("Tap to complete. Touch and hold for more options.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)

            ForEach(Prayer.allCases) { prayer in
                PrayerRow(
                    prayer: prayer,
                    record: metrics.record(for: prayer, on: .now),
                    isEnabled: !periodMode,
                    onToggle: { toggle(prayer) },
                    onStatusChange: { setStatus($0, for: prayer) }
                )
            }
        }
    }

    private var pauseBanner: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tracking is respectfully paused")
                    .font(.subheadline.weight(.semibold))
                Text("These days won’t be treated as missed days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var travelBanner: some View {
        Label("Travel mode is on", systemImage: "airplane")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var gentleFooter: some View {
        HStack(spacing: 14) {
            Image(systemName: completedToday == 5 ? "sparkles" : "heart.fill")
                .foregroundStyle(completedToday == 5 ? AppTheme.gold : AppTheme.accent)

            Text("Every return counts—even the quiet ones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 6)
    }

    private var completionTitle: String {
        switch completedToday {
        case 5: "Alhamdulillah"
        case 4: "One moment remains"
        case 3: "Your rhythm is growing"
        case 2: "A gentle momentum"
        case 1: "A beautiful beginning"
        default: "Begin with one"
        }
    }

    private var completionSubtitle: String {
        switch completedToday {
        case 5: "You made space for all five prayers today."
        case 3...4: "Keep going with the same quiet intention."
        case 1...2: "No pressure. Let the next prayer meet you where you are."
        default: "The day doesn’t need to be perfect. Just begin where you are."
        }
    }

    private var streakMessage: String {
        metrics.currentStreak == 0
            ? "Today is a fresh start"
            : "\(metrics.currentStreak) days in rhythm"
    }

    private func toggle(_ prayer: Prayer) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let record = metrics.record(for: prayer, on: .now) {
                modelContext.delete(record)
            } else {
                modelContext.insert(PrayerRecord(day: .now, prayer: prayer, status: .completed))
            }
            save()
        }
    }

    private func setStatus(_ status: PrayerStatus, for prayer: Prayer) {
        if let record = metrics.record(for: prayer, on: .now) {
            record.status = status
            record.recordedAt = .now
        } else {
            modelContext.insert(PrayerRecord(day: .now, prayer: prayer, status: status))
        }
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
