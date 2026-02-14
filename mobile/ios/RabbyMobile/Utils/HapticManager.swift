import UIKit

/// Centralized haptic feedback manager for Rabby Wallet.
///
/// Provides pre-initialized feedback generators for immediate response and
/// convenience methods mapped to common wallet actions (copy address, send
/// transaction, error states, etc.).
///
/// Usage:
/// ```swift
/// HapticManager.shared.success()   // transaction confirmed
/// HapticManager.shared.error()     // password wrong
/// HapticManager.shared.tap()       // light button tap
/// HapticManager.shared.send()      // sending transaction
/// HapticManager.shared.copy()      // copied address
/// ```
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    // MARK: - Pre-initialized Generators

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Prepare generators so the first trigger has no latency.
        prepareAll()
    }

    // MARK: - Core Methods

    /// Trigger an impact feedback with the given style.
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        switch style {
        case .light:
            impactLight.impactOccurred()
            impactLight.prepare()
        case .medium:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        case .heavy:
            impactHeavy.impactOccurred()
            impactHeavy.prepare()
        case .rigid:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        case .soft:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        @unknown default:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        }
    }

    /// Trigger a notification feedback (success / warning / error).
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    /// Trigger a selection-changed feedback (subtle tick).
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Convenience / Semantic Methods

    /// Positive confirmation (transaction confirmed, backup verified).
    func success() {
        notification(.success)
    }

    /// Error state (wrong password, failed transaction).
    func error() {
        notification(.error)
    }

    /// Warning state (high gas, risky approval).
    func warning() {
        notification(.warning)
    }

    /// Light tap for general button presses.
    func tap() {
        impact(.light)
    }

    /// Feedback when copying an address or text to clipboard.
    func copy() {
        notification(.success)
    }

    /// Heavy feedback for significant actions like sending a transaction.
    func send() {
        impact(.heavy)
    }

    /// Medium feedback for confirming swap / bridge quotes.
    func confirm() {
        impact(.medium)
    }

    /// Subtle tick for scrolling through token lists, switching tabs, etc.
    func tick() {
        selection()
    }

    // MARK: - Private Helpers

    /// Pre-warm all generators so the Taptic Engine is ready.
    private func prepareAll() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
}
