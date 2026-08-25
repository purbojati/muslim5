import CoreLocation
import Foundation
import UserNotifications

private final class PrayerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct PrayerNotificationPreferences: Equatable {
    enum StorageKey {
        static let enabled = "prayerNotificationsEnabled"
        static let fajr = "prayerNotificationFajr"
        static let dhuhr = "prayerNotificationDhuhr"
        static let asr = "prayerNotificationAsr"
        static let maghrib = "prayerNotificationMaghrib"
        static let isha = "prayerNotificationIsha"
    }

    let isEnabled: Bool
    let enabledPrayers: Set<Prayer>
}

@MainActor
final class PrayerNotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastSchedulingError: String?

    private let center = UNUserNotificationCenter.current()
    private let notificationDelegate = PrayerNotificationDelegate()
    private let scheduleService = PrayerScheduleService()
    private let identifierPrefix = "muslim5.prayer."
    private let schedulingDays = 10
    private var synchronizationRevision = 0

    init() {
        center.delegate = notificationDelegate
    }

    var canSchedule: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted && canSchedule
        } catch {
            lastSchedulingError = error.localizedDescription
            await refreshAuthorizationStatus()
            return false
        }
    }

    func synchronize(
        coordinate: CLLocationCoordinate2D?,
        preferences: PrayerNotificationPreferences,
        calculationMethod: String,
        asrMethod: String,
        now: Date = .now,
        timeZone: TimeZone = .autoupdatingCurrent
    ) async {
        synchronizationRevision += 1
        let revision = synchronizationRevision
        await refreshAuthorizationStatus()
        guard revision == synchronizationRevision else { return }

        guard preferences.isEnabled else {
            await removePrayerNotifications()
            return
        }

        guard canSchedule, let coordinate else { return }

        let requests = makeRequests(
            coordinate: coordinate,
            enabledPrayers: preferences.enabledPrayers,
            calculationMethod: calculationMethod,
            asrMethod: asrMethod,
            now: now,
            timeZone: timeZone
        )

        await removePrayerNotifications()
        guard revision == synchronizationRevision else { return }
        lastSchedulingError = nil

        do {
            for request in requests {
                guard revision == synchronizationRevision else { return }
                try await center.add(request)
            }
        } catch {
            lastSchedulingError = error.localizedDescription
        }
    }

    func removePrayerNotifications() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func makeRequests(
        coordinate: CLLocationCoordinate2D,
        enabledPrayers: Set<Prayer>,
        calculationMethod: String,
        asrMethod: String,
        now: Date,
        timeZone: TimeZone
    ) -> [UNNotificationRequest] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfToday = calendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for dayOffset in 0..<schedulingDays {
            guard
                let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                let schedule = scheduleService.dailySchedule(
                    for: coordinate,
                    at: date,
                    timeZone: timeZone,
                    calculationMethod: calculationMethod,
                    asrMethod: asrMethod
                )
            else {
                continue
            }

            for prayer in Prayer.allCases where enabledPrayers.contains(prayer) {
                let prayerTime = schedule.time(for: prayer)
                guard prayerTime > now else { continue }

                requests.append(
                    makeRequest(
                        for: prayer,
                        at: prayerTime,
                        calendar: calendar,
                        timeZone: timeZone
                    )
                )
            }
        }

        return requests
    }

    private func makeRequest(
        for prayer: Prayer,
        at date: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "\(prayer.name) prayer time"
        content.body = "It’s time for \(prayer.name). Take a quiet moment to return."
        content.sound = .default
        content.threadIdentifier = "muslim5.prayer"
        content.userInfo = ["prayer": prayer.rawValue]

        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.calendar = calendar
        components.timeZone = timeZone

        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let dateIdentifier = String(
            format: "%04d-%02d-%02d",
            dayComponents.year ?? 0,
            dayComponents.month ?? 0,
            dayComponents.day ?? 0
        )
        let identifier = "\(identifierPrefix)\(prayer.rawValue).\(dateIdentifier)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
