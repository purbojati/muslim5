import ManagedSettings
import ManagedSettingsUI
import UIKit

final class SalahFocusShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let state = SalahFocusSharedStorage.load()
        let requirement = state.activeRequirement
        let prayerName = requirement?.prayerName ?? "salah"
        let foreground = UIColor(red: 0.97, green: 0.95, blue: 0.88, alpha: 1)
        let secondary = UIColor(red: 0.82, green: 0.84, blue: 0.78, alpha: 1)
        let accent = UIColor(red: 0.78, green: 0.57, blue: 0.27, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemChromeMaterialDark,
            backgroundColor: UIColor(red: 0.035, green: 0.105, blue: 0.09, alpha: 0.96),
            icon: prayerIcon(for: requirement, color: accent),
            title: .init(text: "Make space for \(prayerName)", color: foreground),
            subtitle: .init(
                text: "“Prayer at its proper time.” — Sahih al-Bukhari 527\n\nPray \(prayerName), then mark it complete in Muslim 5 to unlock your apps.",
                color: secondary
            ),
            primaryButtonLabel: .init(text: primaryButtonTitle, color: .white),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: .init(
                text: "Not yet — close this app",
                color: secondary
            )
        )
    }

    private var primaryButtonTitle: String {
        if #available(iOS 26.5, *) {
            return "I’ve prayed — open Muslim 5"
        }
        return "Return to Home Screen"
    }

    private func symbolName(for requirement: SalahFocusRequirement?) -> String {
        switch requirement?.prayerRawValue {
        case "fajr": "sun.horizon.fill"
        case "dhuhr": "sun.max.fill"
        case "asr": "sun.min.fill"
        case "maghrib": "sunset.fill"
        case "isha": "moon.stars.fill"
        default: "hands.sparkles.fill"
        }
    }

    private func prayerIcon(
        for requirement: SalahFocusRequirement?,
        color: UIColor
    ) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(
            pointSize: 44,
            weight: .semibold,
            scale: .large
        )
        return UIImage(
            systemName: symbolName(for: requirement),
            withConfiguration: configuration
        )?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
}
