import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var notificationService: PrayerNotificationService
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"
    @AppStorage(PrayerNotificationPreferences.StorageKey.enabled)
    private var prayerNotificationsEnabled = false
    @AppStorage(PrayerNotificationPreferences.StorageKey.fajr)
    private var fajrNotificationEnabled = true
    @AppStorage(PrayerNotificationPreferences.StorageKey.dhuhr)
    private var dhuhrNotificationEnabled = true
    @AppStorage(PrayerNotificationPreferences.StorageKey.asr)
    private var asrNotificationEnabled = true
    @AppStorage(PrayerNotificationPreferences.StorageKey.maghrib)
    private var maghribNotificationEnabled = true
    @AppStorage(PrayerNotificationPreferences.StorageKey.isha)
    private var ishaNotificationEnabled = true
    @State private var isRequestingNotificationPermission = false
    @State private var isShowingPeriodModeExplanation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: periodModeBinding) {
                        Label {
                            Text("Period mode")
                        } icon: {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                } header: {
                    Text("Life")
                }

                Section {
                    Toggle(isOn: prayerNotificationsBinding) {
                        Label {
                            Text(isRequestingNotificationPermission ? "Requesting permission…" : "Prayer reminders")
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .disabled(isRequestingNotificationPermission)

                    if prayerNotificationsEnabled {
                        ForEach(Prayer.allCases) { prayer in
                            Toggle(isOn: notificationBinding(for: prayer)) {
                                Label {
                                    Text(prayer.name)
                                } icon: {
                                    Image(systemName: prayer.symbol)
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(AppTheme.prayerColor(for: prayer))
                                }
                            }
                            .disabled(!notificationService.canSchedule)
                        }
                    }

                    if notificationService.authorizationStatus == .denied {
                        Label {
                            Text("Notifications are off in iPhone Settings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(.orange)
                        }

                        Button("Open iPhone Settings") {
                            openNotificationSettings()
                        }
                    }

                    if let error = notificationService.lastSchedulingError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Sound and vibration follow your iPhone settings.")
                }

                Section {
                    Picker("Asr method", selection: $asrMethod) {
                        Text("Standard").tag("standard")
                        Text("Hanafi").tag("hanafi")
                    }
                    .onChange(of: asrMethod) {
                        HapticFeedback.selection()
                    }

                    Text("Standard is used by Shafi’i, Maliki, and Hanbali traditions. Hanafi calculates Asr later. Standard usually matches local practice in Indonesia.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Calculation method", selection: $calculationMethod) {
                        Text("Use local convention").tag("local")
                        Text("Muslim World League").tag("mwl")
                        Text("Umm al-Qura").tag("ummAlQura")
                        Text("Singapore (MUIS)").tag("muis")
                    }
                    .onChange(of: calculationMethod) {
                        HapticFeedback.selection()
                    }
                } header: {
                    Text("Prayer times")
                }

                Section("Privacy") {
                    Label("Stored on this iPhone", systemImage: "iphone")
                    Label("No account", systemImage: "person.crop.circle.badge.checkmark")
                    Label("No leaderboard", systemImage: "eye.slash")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("You")
            .task {
                await notificationService.refreshAuthorizationStatus()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await notificationService.refreshAuthorizationStatus()
                }
            }
            .sheet(isPresented: $isShowingPeriodModeExplanation) {
                PeriodModeExplanationSheet {
                    setPeriodMode(true)
                    isShowingPeriodModeExplanation = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        case (nil, nil):
            return "—"
        }
    }

    private var prayerNotificationsBinding: Binding<Bool> {
        Binding(
            get: { prayerNotificationsEnabled },
            set: { newValue in
                guard newValue else {
                    prayerNotificationsEnabled = false
                    HapticFeedback.impact(.soft)
                    return
                }

                isRequestingNotificationPermission = true
                Task {
                    let allowed: Bool
                    if notificationService.canSchedule {
                        allowed = true
                    } else {
                        allowed = await notificationService.requestAuthorization()
                    }

                    prayerNotificationsEnabled = allowed
                    isRequestingNotificationPermission = false
                    HapticFeedback.notification(allowed ? .success : .warning)
                }
            }
        )
    }

    private func notificationBinding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { isNotificationEnabled(for: prayer) },
            set: { newValue in
                setNotificationEnabled(newValue, for: prayer)
                HapticFeedback.selection()
            }
        )
    }

    private func isNotificationEnabled(for prayer: Prayer) -> Bool {
        switch prayer {
        case .fajr: fajrNotificationEnabled
        case .dhuhr: dhuhrNotificationEnabled
        case .asr: asrNotificationEnabled
        case .maghrib: maghribNotificationEnabled
        case .isha: ishaNotificationEnabled
        }
    }

    private func setNotificationEnabled(_ enabled: Bool, for prayer: Prayer) {
        switch prayer {
        case .fajr: fajrNotificationEnabled = enabled
        case .dhuhr: dhuhrNotificationEnabled = enabled
        case .asr: asrNotificationEnabled = enabled
        case .maghrib: maghribNotificationEnabled = enabled
        case .isha: ishaNotificationEnabled = enabled
        }
    }

    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString) else {
            return
        }
        openURL(settingsURL)
    }

    private var periodModeBinding: Binding<Bool> {
        Binding(
            get: { periodMode },
            set: { newValue in
                if newValue && !periodMode {
                    isShowingPeriodModeExplanation = true
                } else {
                    setPeriodMode(newValue)
                }
            }
        )
    }

    private func setPeriodMode(_ enabled: Bool) {
        periodMode = enabled
        if enabled {
            if pauses.first(where: { $0.endDay == nil && $0.reason == "period" }) == nil {
                modelContext.insert(TrackingPause())
            }
        } else {
            pauses
                .filter { $0.endDay == nil && $0.reason == "period" }
                .forEach { $0.endDay = Calendar.current.startOfDay(for: .now) }
        }

        do {
            try modelContext.save()
            HapticFeedback.impact(enabled ? .medium : .soft)
        } catch {
            HapticFeedback.notification(.error)
        }
    }
}

private struct PeriodModeExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.accent)

                Text("Turn on Period Mode?")
                    .font(.title2.bold())

                Text("While it’s on:")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                explanationRow("Daily prayer tracking pauses", symbol: "pause.fill")
                explanationRow("Paused days won’t break your streak", symbol: "flame.fill")
                explanationRow("Everything stays on this iPhone", symbol: "lock.fill")
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button("Turn On Period Mode", action: onEnable)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Not Now", role: .cancel) {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
    }

    private func explanationRow(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
            .accessibilityElement(children: .combine)
    }
}
