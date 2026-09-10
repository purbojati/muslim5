import UIKit

@MainActor
enum HapticFeedback {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        selectionGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        softImpactGenerator.prepare()
        rigidImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func impact(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        intensity: CGFloat = 1
    ) {
        let generator = switch style {
        case .light: lightImpactGenerator
        case .medium: mediumImpactGenerator
        case .heavy: heavyImpactGenerator
        case .soft: softImpactGenerator
        case .rigid: rigidImpactGenerator
        @unknown default: lightImpactGenerator
        }
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }
}
