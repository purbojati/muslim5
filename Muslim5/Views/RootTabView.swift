import SwiftData
import SwiftUI

struct RootTabView: View {
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
    @StateObject private var salahFocusService = SalahFocusService()
    @StateObject private var sharingService = SharingService()

    private enum AppTab: Hashable {
        case today
        case qibla
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
        .environmentObject(salahFocusService)
        .environmentObject(sharingService)
        .task {
            locationProvider.start()
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
            synchronizeSalahFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task {
                await synchronizeNotifications()
                synchronizeSalahFocus()
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

            QiblaView()
                .tabItem {
                    Label("Qibla", systemImage: "location.north.circle.fill")
                }
                .tag(AppTab.qibla)

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

    private struct NotificationConfiguration: Equatable {
        let preferences: PrayerNotificationPreferences
        let calculationMethod: String
        let asrMethod: String
    }
}
