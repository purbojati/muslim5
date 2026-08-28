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
        let prayerName = state.activeRequirement?.prayerName ?? "salah"
        let foreground = UIColor.label
        let secondary = UIColor.secondaryLabel
        let accent = UIColor(red: 0.16, green: 0.45, blue: 0.38, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.94),
            icon: UIImage(systemName: "lock.shield.fill"),
            title: .init(text: "It’s time for \(prayerName)", color: foreground),
            subtitle: .init(
                text: "Complete your salah, then record it in Muslim 5 to continue.",
                color: secondary
            ),
            primaryButtonLabel: .init(text: primaryButtonTitle, color: .white),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: .init(
                text: "Muslim 5 remains available from your Home Screen.",
                color: secondary
            )
        )
    }

    private var primaryButtonTitle: String {
        if #available(iOS 26.5, *) {
            return "Open Muslim 5"
        }
        return "Close App"
    }
}

