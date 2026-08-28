import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var notificationService: PrayerNotificationService
    @EnvironmentObject private var salahFocusService: SalahFocusService
    @EnvironmentObject private var sharingService: SharingService
    @EnvironmentObject private var locationProvider: LocationProvider
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
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
    @State private var selectedFeature: FeatureDestination?

    private enum FeatureDestination: Hashable {
        case qibla
        case prayerCircle
        case salahFocus
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: featureColumns, spacing: 12) {
                        Button {
                            selectedFeature = .qibla
                        } label: {
                            FeatureCard(
                                title: "Qibla",
                                detail: "Find the prayer direction",
                                symbol: "location.north.circle.fill",
                                tint: AppTheme.qiblaFeature
                            )
                        }

                        Button {
                            selectedFeature = .prayerCircle
                        } label: {
                            FeatureCard(
                                title: "Salah Circle",
                                detail: sharingStatus,
                                symbol: "person.2.fill",
                                tint: AppTheme.prayerCircleFeature
                            )
                        }

                        SalahFocusFeatureCard(
                            isOn: salahFocusToggleBinding,
                            detail: salahFocusStatus,
                            onOpen: { selectedFeature = .salahFocus }
                        )

                        PeriodModeFeatureCard(
                            isOn: periodModeBinding,
                            detail: periodMode ? "Tracking is paused" : "Pause tracking when needed"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Features")
                }

                Section {
                    Button(action: handleLocationAction) {
                        LabeledContent {
                            Text(locationLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } label: {
                            Label {
                                Text("Prayer location")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: locationSymbol)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityLabel("Prayer location: \(locationLabel)")
                    .accessibilityHint("Updates the location used for prayer times")

                    NavigationLink {
                        PrayerTimesSettingsView()
                    } label: {
                        Label {
                            Text("Prayer Times")
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: prayerNotificationsBinding) {
                        Label {
                            Text(isRequestingNotificationPermission ? "Requesting permission…" : "Prayer reminders")
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.secondary)
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
                        Label {
                            Text(error)
                                .foregroundStyle(.orange)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.footnote)
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    Text("A gentle reminder at each selected prayer time. Sound and vibration follow your iPhone settings.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("Made with care by a fellow Muslim in Indonesia 🇮🇩")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Others")
            .navigationDestination(item: $selectedFeature) { feature in
                switch feature {
                case .qibla:
                    QiblaView()
                case .prayerCircle:
                    SharingSettingsView()
                case .salahFocus:
                    SalahFocusSettingsView()
                }
            }
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

    private var locationLabel: String {
        switch locationProvider.state {
        case .requesting:
            return "Locating…"
        case .denied:
            return "Location off"
        case .unavailable where locationProvider.cityName == nil:
            return "Unavailable"
        default:
            return locationProvider.cityName ?? "Current location"
        }
    }

    private var locationSymbol: String {
        locationProvider.state == .denied ? "location.slash.fill" : "location.fill"
    }

    private var featureColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var sharingStatus: String {
        guard sharingService.isConfigured else { return "Server not configured" }
        guard let profile = sharingService.profile else { return "Not set up" }
        let count = sharingService.linkedUsers.count
        return "\(profile.nickname) · \(count) linked"
    }

    private var salahFocusStatus: String {
        guard salahFocusService.isAuthorized else { return "Not set up" }
        guard salahFocusService.isEnabled else { return "Off" }
        if let prayer = salahFocusService.activePrayerName {
            return "Waiting for \(prayer)"
        }
        return "Ready for the next salah"
    }

    private var salahFocusToggleBinding: Binding<Bool> {
        Binding(
            get: { salahFocusService.isEnabled },
            set: { newValue in
                guard newValue else {
                    salahFocusService.disable()
                    HapticFeedback.impact(.soft)
                    return
                }

                guard salahFocusService.isAuthorized else {
                    selectedFeature = .salahFocus
                    HapticFeedback.impact(.soft)
                    return
                }

                let enabled = salahFocusService.enable()
                HapticFeedback.notification(enabled ? .success : .warning)
            }
        )
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

    private func handleLocationAction() {
        HapticFeedback.impact(.light)

        if locationProvider.state == .denied,
           let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            openURL(settingsURL)
        } else {
            locationProvider.requestLocation()
        }
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
        salahFocusService.setPeriodMode(enabled)
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

private struct FeatureCard: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 5)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct PeriodModeFeatureCard: View {
    @Binding var isOn: Bool
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "pause.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.periodModeFeature)
                    .frame(width: 38, height: 38)
                    .background(
                        AppTheme.periodModeFeature.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                Spacer(minLength: 4)

                Toggle("Period Mode", isOn: $isOn)
                    .labelsHidden()
                    .controlSize(.mini)
                    .tint(AppTheme.periodModeFeature)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("Period Mode")
                    .font(.headline)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct SalahFocusFeatureCard: View {
    @Binding var isOn: Bool
    let detail: String
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.salahFocusFeature)
                    .frame(width: 38, height: 38)
                    .background(
                        AppTheme.salahFocusFeature.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                Spacer(minLength: 4)

                Toggle("Salah Focus", isOn: $isOn)
                    .labelsHidden()
                    .controlSize(.mini)
                    .tint(AppTheme.salahFocusFeature)
            }

            Spacer(minLength: 0)

            Button(action: onOpen) {
                HStack(alignment: .bottom, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Salah Focus")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Salah Focus settings")
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct PrayerTimesSettingsView: View {
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"

    var body: some View {
        Form {
            Section {
                Picker("Asr method", selection: $asrMethod) {
                    Text("Standard").tag("standard")
                    Text("Hanafi").tag("hanafi")
                }
                .onChange(of: asrMethod) {
                    HapticFeedback.selection()
                }
            } header: {
                Text("Asr")
            } footer: {
                Text("Standard is used by Shafi’i, Maliki, and Hanbali traditions. Hanafi calculates Asr later. Standard usually matches local practice in Indonesia.")
            }

            Section {
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
                Text("Calculation")
            }
        }
        .navigationTitle("Prayer Times")
        .navigationBarTitleDisplayMode(.inline)
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
                    .foregroundStyle(AppTheme.periodModeFeature)

                Text("Pause tracking for your period?")
                    .font(.title2.bold())

                Text("While Period Mode is on:")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                explanationRow("Salah tracking will pause", symbol: "pause.fill")
                explanationRow("These days won’t affect your streak", symbol: "flame.fill")
                explanationRow("Your data remains on this iPhone", symbol: "lock.fill")
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
