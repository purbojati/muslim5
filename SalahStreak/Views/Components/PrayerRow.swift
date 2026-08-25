import SwiftUI

struct PrayerRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let prayer: Prayer
    let prayerTime: Date?
    let record: PrayerRecord?
    let isEnabled: Bool
    let onToggle: () -> Void
    let onStatusChange: (PrayerStatus) -> Void

    var body: some View {
        Button(action: onToggle) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityLayout
                } else {
                    regularLayout
                }
            }
            .contentShape(Rectangle())
            .padding(15)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PrayerRowButtonStyle())
        .disabled(!isEnabled)
        .contextMenu {
            if isEnabled {
                ForEach(PrayerStatus.allCases, id: \.self) { status in
                    Button {
                        onStatusChange(status)
                    } label: {
                        Label(status.title, systemImage: status.symbol)
                    }
                }

                if record != nil {
                    Button(role: .destructive, action: onToggle) {
                        Label("Clear", systemImage: "xmark")
                    }
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isEnabled ? "Double tap to toggle. Touch and hold for more statuses." : "Tracking is paused.")
    }

    private var regularLayout: some View {
        HStack(spacing: 16) {
            prayerIcon
            prayerLabel
            Spacer()
            prayerTimeLabel
            toggleIcon
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                prayerIcon
                Text(prayer.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                toggleIcon
            }

            HStack(alignment: .firstTextBaseline) {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                prayerTimeLabel
            }
        }
    }

    private var prayerIcon: some View {
        let color = AppTheme.prayerColor(for: prayer)

        return ZStack {
            Circle()
                .fill(color.opacity(record == nil ? 0.12 : 0.20))
                .overlay {
                    Circle()
                        .strokeBorder(color.opacity(record == nil ? 0.16 : 0.28), lineWidth: 1)
                }
                .frame(width: 46, height: 46)

            Image(systemName: prayer.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private var prayerLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(prayer.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var prayerTimeLabel: some View {
        if let prayerTime {
            Text(prayerTime, format: .dateTime.hour().minute())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var toggleIcon: some View {
        let color = AppTheme.prayerColor(for: prayer)

        return ZStack {
            Circle()
                .fill(record == nil ? color.opacity(0.11) : AppTheme.success)
                .frame(width: 40, height: 40)

            Image(systemName: record == nil ? "plus" : "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(record == nil ? color : .white)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var statusMessage: String {
        guard let status = record?.status else { return "Ready when you are" }
        return switch status {
        case .completed: "Alhamdulillah"
        case .late: "Prayed a little later"
        case .madeUp: "Made up with care"
        }
    }

    private var accessibilityLabel: String {
        let time = prayerTime?.formatted(date: .omitted, time: .shortened)
        return [prayer.name, time, record?.status.title ?? "not recorded"]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct PrayerRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
