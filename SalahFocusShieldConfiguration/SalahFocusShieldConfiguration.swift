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
        let prayerName = requirement?.prayerName ?? String(localized: "salah")
        let theme = shieldTheme(for: requirement)
        let foreground = UIColor(red: 0.97, green: 0.95, blue: 0.88, alpha: 1)
        let secondary = UIColor(red: 0.82, green: 0.84, blue: 0.78, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemChromeMaterialDark,
            backgroundColor: theme.background.withAlphaComponent(0.96),
            icon: prayerIcon(for: requirement, color: theme.accent),
            title: .init(text: String(localized: "Make space for \(prayerName)"), color: foreground),
            subtitle: .init(
                text: String(localized: "“Prayer at its proper time.” — Sahih al-Bukhari 527\n\nPray \(prayerName), then mark it complete in Muslim 5 to unlock your apps."),
                color: secondary
            ),
            primaryButtonLabel: .init(text: primaryButtonTitle, color: theme.buttonLabel),
            primaryButtonBackgroundColor: theme.accent,
            secondaryButtonLabel: .init(
                text: String(localized: "Snooze for 30 minutes"),
                color: secondary
            )
        )
    }

    private var primaryButtonTitle: String {
        if #available(iOS 26.5, *) {
            return String(localized: "I’ve prayed — open Muslim 5")
        }
        return String(localized: "Return to Home Screen")
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

    private func shieldTheme(for requirement: SalahFocusRequirement?) -> ShieldTheme {
        switch requirement?.prayerRawValue {
        case "fajr":
            ShieldTheme(
                background: UIColor(red: 0.055, green: 0.085, blue: 0.18, alpha: 1),
                accent: UIColor(red: 0.48, green: 0.70, blue: 0.90, alpha: 1)
            )
        case "dhuhr":
            ShieldTheme(
                background: UIColor(red: 0.16, green: 0.095, blue: 0.035, alpha: 1),
                accent: UIColor(red: 0.91, green: 0.64, blue: 0.25, alpha: 1)
            )
        case "asr":
            ShieldTheme(
                background: UIColor(red: 0.18, green: 0.065, blue: 0.025, alpha: 1),
                accent: UIColor(red: 0.94, green: 0.47, blue: 0.18, alpha: 1)
            )
        case "maghrib":
            ShieldTheme(
                background: UIColor(red: 0.15, green: 0.035, blue: 0.085, alpha: 1),
                accent: UIColor(red: 0.91, green: 0.42, blue: 0.43, alpha: 1)
            )
        case "isha":
            ShieldTheme(
                background: UIColor(red: 0.025, green: 0.045, blue: 0.13, alpha: 1),
                accent: UIColor(red: 0.62, green: 0.59, blue: 0.94, alpha: 1)
            )
        default:
            ShieldTheme(
                background: UIColor(red: 0.035, green: 0.105, blue: 0.09, alpha: 1),
                accent: UIColor(red: 0.78, green: 0.57, blue: 0.27, alpha: 1)
            )
        }
    }
}

private struct ShieldTheme {
    let background: UIColor
    let accent: UIColor

    var buttonLabel: UIColor {
        UIColor(red: 0.025, green: 0.035, blue: 0.035, alpha: 1)
    }
}
