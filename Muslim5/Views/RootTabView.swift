import SwiftUI

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var selectedTab = AppTab.today
    @StateObject private var locationProvider = LocationProvider()
    @StateObject private var notificationService = PrayerNotificationService()

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
        .task {
            locationProvider.start()
            await synchronizeNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            locationProvider.requestLocation()
            Task { await synchronizeNotifications() }
        }
        .onChange(of: locationFingerprint) {
            Task { await synchronizeNotifications() }
        }
        .onChange(of: notificationConfiguration) {
            Task { await synchronizeNotifications() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await synchronizeNotifications() }
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
                    Label("You", systemImage: "person.crop.circle")
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

    private struct NotificationConfiguration: Equatable {
        let preferences: PrayerNotificationPreferences
        let calculationMethod: String
        let asrMethod: String
    }
}
