import SwiftUI

struct PrayerRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var completionBurstTrigger = 0

    let prayer: Prayer
    let prayerTime: Date?
    let record: PrayerRecord?
    let isVisuallyCompleted: Bool
    let linkedUsers: [SharingUser]
    let isEnabled: Bool
    let hasPrayerTimePassed: Bool
    let onToggle: () -> Void
    let onStatusChange: (PrayerStatus) -> Void
    let onAttendanceChange: (PrayerAttendance) -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: linkedUsers.isEmpty ? 0 : 8) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityLayout
                    } else {
                        regularLayout
                    }
                }

                if !linkedUsers.isEmpty {
                    PrayerCompanionsView(users: linkedUsers)
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
                Section("Prayer time") {
                    ForEach(PrayerStatus.allCases, id: \.self) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            Label(status.title, systemImage: selectionSymbol(for: status))
                        }
                    }
                }

                Section("Attendance") {
                    ForEach(PrayerAttendance.allCases, id: \.self) { attendance in
                        Button {
                            onAttendanceChange(attendance)
                        } label: {
                            Label(attendance.title, systemImage: selectionSymbol(for: attendance))
                        }
                    }
                }

                if isVisuallyCompleted {
                    Button(role: .destructive, action: onToggle) {
                        Label("Clear", systemImage: "xmark")
                    }
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(
            isEnabled
                ? String(localized: "Double tap to toggle. Touch and hold for more statuses.")
                : String(localized: "Tracking is paused.")
        )
        .onChange(of: isVisuallyCompleted) { wasCompleted, isCompleted in
            guard !wasCompleted, isCompleted, !reduceMotion else { return }
            completionBurstTrigger += 1
        }
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
                .fill(color.opacity(isVisuallyCompleted ? 0.20 : 0.12))
                .overlay {
                    Circle()
                        .strokeBorder(
                            color.opacity(isVisuallyCompleted ? 0.28 : 0.16),
                            lineWidth: 1
                        )
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
            PrayerCompletionBurst(
                color: color,
                trigger: completionBurstTrigger
            )

            Circle()
                .fill(isVisuallyCompleted ? AppTheme.success : color.opacity(0.11))
                .frame(width: 40, height: 40)

            Image(systemName: isVisuallyCompleted ? "checkmark" : "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isVisuallyCompleted ? .white : color)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var statusMessage: String {
        guard isVisuallyCompleted else {
            return hasPrayerTimePassed
                ? prayer.passedTimeEncouragement
                : String(localized: "Ready when you are")
        }

        guard let record else { return String(localized: "Alhamdulillah") }

        let timingMessage = switch record.status {
        case .completed: String(localized: "Alhamdulillah")
        case .late: String(localized: "Prayed a little later")
        case .madeUp: String(localized: "Prayed after time")
        }

        guard let attendance = record.attendance else { return timingMessage }
        return "\(timingMessage) · \(attendance.shortTitle)"
    }

    private var accessibilityLabel: String {
        let time = prayerTime?.formatted(date: .omitted, time: .shortened)
        let linkedNames = linkedUsers.isEmpty
            ? nil
            : String(localized: "Completed by \(linkedUsers.map(\.nickname).joined(separator: ", "))")
        return [prayer.name, time, record?.status.title ?? statusMessage, record?.attendance?.title, linkedNames]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func selectionSymbol(for status: PrayerStatus) -> String {
        record?.status == status ? "checkmark.circle.fill" : status.symbol
    }

    private func selectionSymbol(for attendance: PrayerAttendance) -> String {
        record?.attendance == attendance ? "checkmark.circle.fill" : attendance.symbol
    }
}

private struct PrayerCompletionBurst: View {
    let color: Color
    let trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(0.72))
                    .frame(width: 2, height: 5)
                    .offset(y: -27)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
        .frame(width: 54, height: 54)
        .phaseAnimator(BurstPhase.allCases, trigger: trigger) { content, phase in
            content
                .scaleEffect(phase.scale)
                .opacity(phase.opacity)
        } animation: { phase in
            .timingCurve(0.23, 1, 0.32, 1, duration: phase.duration)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private enum BurstPhase: CaseIterable {
        case idle
        case bright
        case dispersed

        var scale: CGFloat {
            switch self {
            case .idle: 0.88
            case .bright: 1
            case .dispersed: 1.22
            }
        }

        var opacity: Double {
            switch self {
            case .idle, .dispersed: 0
            case .bright: 1
            }
        }

        var duration: Double {
            switch self {
            case .idle: 0
            case .bright: 0.08
            case .dispersed: 0.24
            }
        }
    }
}

private struct PrayerCompanionsView: View {
    let users: [SharingUser]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(users.prefix(5)) { user in
                ZStack {
                    SharingAvatarView(user: user, size: 28)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "\(user.nickname) completed this prayer"))
            }

            if users.count > 5 {
                Text("+\(users.count - 5)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1), in: Circle())
                    .accessibilityLabel(String(localized: "\(users.count - 5) more people completed this prayer"))
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 62)
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
