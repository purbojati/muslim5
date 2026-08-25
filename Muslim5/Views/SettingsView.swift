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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: periodModeBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Period mode")
                                Text("Pause tracking without breaking your streak")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                } header: {
                    Text("Support for your life")
                } footer: {
                    Text("Period information is private and remains only on this device.")
                }

                Section {
                    Toggle(isOn: prayerNotificationsBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Prayer reminders")
                                Text(notificationStatusText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .disabled(isRequestingNotificationPermission)

                    if prayerNotificationsEnabled {
                        ForEach(Prayer.allCases) { prayer in
                            Toggle(isOn: notificationBinding(for: prayer)) {
                                Label(prayer.name, systemImage: prayer.symbol)
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
                    Text("Prayer reminders")
                } footer: {
                    Text("Reminders arrive at each selected prayer time using your location and calculation preferences.")
                }

                Section {
                    Picker("Asr method", selection: $asrMethod) {
                        Text("Standard").tag("standard")
                        Text("Hanafi").tag("hanafi")
                    }
                    .onChange(of: asrMethod) {
                        HapticFeedback.selection()
                    }

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
                    Text("Your prayer practice")
                } footer: {
                    Text("These preferences shape the offline prayer times shown on Today.")
                }

                Section("Your privacy") {
                    Label("On-device storage", systemImage: "iphone.and.arrow.forward")
                    Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
                    Label("No public leaderboard", systemImage: "eye.slash")
                }

                Section {
                    LabeledContent("Version", value: "0.1.0")
                } footer: {
                    Text("Five moments. Every day. Keep returning.")
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

    private var notificationStatusText: String {
        if isRequestingNotificationPermission {
            return "Waiting for permission"
        }

        switch notificationService.authorizationStatus {
        case .authorized, .ephemeral:
            return prayerNotificationsEnabled ? "On" : "Off"
        case .provisional:
            return prayerNotificationsEnabled ? "Delivered quietly" : "Off"
        case .denied:
            return "Permission required"
        case .notDetermined:
            return "Choose which prayers can remind you"
        @unknown default:
            return prayerNotificationsEnabled ? "On" : "Off"
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
                periodMode = newValue
                if newValue {
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
                    HapticFeedback.impact(newValue ? .medium : .soft)
                } catch {
                    HapticFeedback.notification(.error)
                }
            }
        )
    }
}
