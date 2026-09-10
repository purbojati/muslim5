import CloudKit
import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PrayerRecord.day, order: .reverse) private var records: [PrayerRecord]
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
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
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"
    @AppStorage("periodMode") private var periodMode = false
    @State private var selectedTab = AppTab.today
    @StateObject private var locationProvider = LocationProvider()
    @StateObject private var notificationService = PrayerNotificationService()
    @StateObject private var iCloudStatusService = ICloudStatusService()
    @StateObject private var salahFocusService = SalahFocusService()
    @StateObject private var sharingService = SharingService()
    @State private var salahFocusSynchronizationTask: Task<Void, Never>?
    @State private var cloudNormalizationTask: Task<Void, Never>?

    private enum AppTab: Hashable {
        case today
        case journey
        case settings
    }

    @ViewBuilder
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                tabs
                    .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                tabs
            }
        }
        .environmentObject(locationProvider)
        .environmentObject(notificationService)
        .environmentObject(iCloudStatusService)
        .environmentObject(salahFocusService)
        .environmentObject(sharingService)
        .task {
            HapticFeedback.prepare()
            locationProvider.start()
            normalizeCloudDataIfNeeded()
            await iCloudStatusService.refresh()
            await sharingService.start()
            await synchronizeNotifications()
            await salahFocusService.prepareForLaunch()
            synchronizeSalahFocus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            locationProvider.requestLocation()
            Task {
                await sharingService.refreshLinks()
                await synchronizeNotifications()
                await salahFocusService.prepareForLaunch()
                synchronizeSalahFocus()
            }
        }
        .onChange(of: locationFingerprint) {
            Task { await synchronizeNotifications() }
        }
        .onChange(of: notificationConfiguration) {
            Task { await synchronizeNotifications() }
        }
        .onChange(of: salahFocusSynchronizationKey) {
            scheduleSalahFocusSynchronization()
        }
        .onChange(of: cloudDataFingerprint) {
            scheduleCloudDataNormalization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task {
                await synchronizeNotifications()
                synchronizeSalahFocus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            Task {
                await iCloudStatusService.refresh()
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(AppTab.today)

            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                }
                .tag(AppTab.journey)

            SettingsView()
                .tabItem {
                    Label("Others", systemImage: "ellipsis.circle")
                }
                .tag(AppTab.settings)
        }
        .onChange(of: selectedTab) {
            HapticFeedback.selection()
        }
    }

    private var notificationConfiguration: NotificationConfiguration {
        NotificationConfiguration(
            preferences: PrayerNotificationPreferences(
                isEnabled: prayerNotificationsEnabled,
                enabledPrayers: Set(
                    Prayer.allCases.filter { isNotificationEnabled(for: $0) }
                )
            ),
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
    }

    private var locationFingerprint: String {
        guard let coordinate = locationProvider.coordinate else { return "unavailable" }
        return "\(coordinate.latitude),\(coordinate.longitude)"
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

    private func synchronizeNotifications() async {
        let configuration = notificationConfiguration
        await notificationService.synchronize(
            coordinate: locationProvider.coordinate,
            preferences: configuration.preferences,
            calculationMethod: configuration.calculationMethod,
            asrMethod: configuration.asrMethod
        )
    }

    private var salahFocusSynchronizationKey: String {
        guard salahFocusService.isEnabled else {
            return "disabled|\(salahFocusService.configurationRevision)|\(periodMode)"
        }

        let completionFingerprint = records.map(\.id).sorted().joined(separator: ",")
        let pauseFingerprint = pauses.map {
            "\($0.id.uuidString):\($0.startDay.timeIntervalSince1970):\($0.endDay?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: ",")
        return [
            locationFingerprint,
            calculationMethod,
            asrMethod,
            periodMode ? "paused" : "active",
            String(salahFocusService.configurationRevision),
            completionFingerprint,
            pauseFingerprint
        ].joined(separator: "|")
    }

    private func synchronizeSalahFocus() {
        salahFocusService.synchronize(
            coordinate: locationProvider.coordinate,
            records: records,
            pauses: pauses,
            periodMode: periodMode,
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
    }

    private func scheduleSalahFocusSynchronization() {
        salahFocusSynchronizationTask?.cancel()
        salahFocusSynchronizationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                synchronizeSalahFocus()
            } catch {
                // A newer data change replaced this synchronization pass.
            }
        }
    }

    private var cloudDataFingerprint: String {
        let recordFingerprint = records.map {
            "\($0.id):\($0.statusRawValue):\($0.attendanceRawValue ?? ""):" +
                String($0.recordedAt.timeIntervalSince1970)
        }.sorted().joined(separator: ",")
        let pauseFingerprint = pauses.map {
            "\($0.id.uuidString):\($0.reason):\($0.startDay.timeIntervalSince1970):" +
                String($0.endDay?.timeIntervalSince1970 ?? 0)
        }.sorted().joined(separator: ",")
        return recordFingerprint + "|" + pauseFingerprint
    }

    private func normalizeCloudDataIfNeeded() {
        guard ICloudSyncDataNormalizer.normalize(
            records: records,
            pauses: pauses,
            in: modelContext
        ) else { return }

        do {
            try modelContext.save()
            iCloudStatusService.markLocalChangePending()
        } catch {
            #if DEBUG
            print("Could not normalize iCloud data: \(error)")
            #endif
        }
    }

    private func scheduleCloudDataNormalization() {
        cloudNormalizationTask?.cancel()
        cloudNormalizationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                normalizeCloudDataIfNeeded()
            } catch {
                // A newer model update replaced this normalization pass.
            }
        }
    }

    private struct NotificationConfiguration: Equatable {
        let preferences: PrayerNotificationPreferences
        let calculationMethod: String
        let asrMethod: String
    }
}
