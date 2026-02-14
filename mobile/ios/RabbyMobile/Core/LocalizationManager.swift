import Foundation
import Combine

/// Notification for locale changes
extension Notification.Name {
    static let localeDidChange = Notification.Name("LocaleDidChange")
}

/// Localization Manager - Handles i18n for the app
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var currentLocale: String = "en"
    @Published private(set) var translations: [String: String] = [:]

    // Reverse-lookup map built from `en.json`: English value -> translation key.
    // This lets us write `L("Cancel")` or `"Cancel".localized` without manually converting
    // the literal to its snake_case key.
    private var reverseEnglishValueToKey: [String: String] = [:]
    private let reverseMapLock = NSLock()

    static let supportedLocales = [
        "en",       // English
        "zh-CN",    // Chinese Simplified
        "zh-HK",    // Chinese Traditional (Hong Kong)
        "ja",       // Japanese
        "ko",       // Korean
        "de",       // German
        "es",       // Spanish
        "fr-FR",    // French
        "pt",       // Portuguese (European)
        "pt-BR",    // Portuguese (Brazilian)
        "ru",       // Russian
        "tr",       // Turkish
        "vi",       // Vietnamese
        "id",       // Indonesian
        "uk-UA"     // Ukrainian
    ]
    private let availableLocales = LocalizationManager.supportedLocales
    private let queue = DispatchQueue(label: "com.rabby.localization", qos: .userInitiated)

    private init() {
        // Load initial locale synchronously so translations are available on first render.
        // PreferenceManager may override via .localeDidChange notification afterwards.
        let initialLocale = Self.bestSupportedLocale()
        currentLocale = initialLocale
        translations = loadTranslations(for: initialLocale) ?? [:]

        // Listen for locale change notifications from PreferenceManager
        NotificationCenter.default.addObserver(
            forName: .localeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let locale = notification.userInfo?["locale"] as? String {
                self?.setLocale(locale)
            }
        }
    }

    /// Pick the best supported locale from iOS preferred languages.
    static func bestSupportedLocale(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        // Exact match first (e.g. "pt-BR")
        for lang in preferredLanguages {
            if supportedLocales.contains(lang) { return lang }
        }

        // Normalize and match common iOS variants (BCP-47).
        for lang in preferredLanguages {
            let lower = lang.lowercased()

            // Chinese: iOS often uses script codes (zh-Hans / zh-Hant)
            if lower.hasPrefix("zh-hans") || lower.hasPrefix("zh-cn") {
                return supportedLocales.contains("zh-CN") ? "zh-CN" : "en"
            }
            if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-hk") || lower.hasPrefix("zh-tw") {
                return supportedLocales.contains("zh-HK") ? "zh-HK" : "en"
            }

            if lower.hasPrefix("pt-br") {
                return supportedLocales.contains("pt-BR") ? "pt-BR" : "pt"
            }

            // Fall back by language code.
            let languageCode = lower.split(separator: "-").first.map(String.init) ?? lower
            switch languageCode {
            case "en": return "en"
            case "ja": return "ja"
            case "ko": return "ko"
            case "de": return "de"
            case "es": return "es"
            case "fr": return supportedLocales.contains("fr-FR") ? "fr-FR" : "en"
            case "pt": return supportedLocales.contains("pt") ? "pt" : "pt-BR"
            case "ru": return "ru"
            case "tr": return "tr"
            case "vi": return "vi"
            case "id": return "id"
            case "uk": return supportedLocales.contains("uk-UA") ? "uk-UA" : "en"
            default:
                break
            }
        }

        return "en"
    }

    /// Set current locale and load translations
    func setLocale(_ locale: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let targetLocale: String
            if self.availableLocales.contains(locale) {
                targetLocale = locale
            } else {
                print("[Localization] Locale '\(locale)' not supported, falling back to 'en'")
                targetLocale = "en"
            }

            let newTranslations = self.loadTranslations(for: targetLocale) ?? [:]
            DispatchQueue.main.async {
                self.currentLocale = targetLocale
                self.translations = newTranslations
            }
        }
    }

    /// Load translations from JSON file
    private func loadTranslations(for locale: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: locale, ofType: "json", inDirectory: "locales"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[Localization] Failed to load locale file for '\(locale)'")
            return nil
        }

        // Flatten nested JSON into dot notation keys
        let translations = flattenJSON(json)
        print("[Localization] Loaded \(translations.count) translations for '\(locale)'")
        return translations
    }

    /// Flatten nested JSON dictionary with dot notation
    private func flattenJSON(_ json: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in json {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"

            if let stringValue = value as? String {
                result[fullKey] = stringValue
            } else if let nestedDict = value as? [String: Any] {
                let nested = flattenJSON(nestedDict, prefix: fullKey)
                result.merge(nested) { _, new in new }
            }
        }

        return result
    }

    /// Get translated string for key
    func t(_ key: String, defaultValue: String? = nil) -> String {
        if let direct = translations[key] { return direct }

        // Fallback: treat `key` as an English literal value and map it back to a real key.
        if let mappedKey = englishValueToKey(key), let mapped = translations[mappedKey] {
            return mapped
        }

        return defaultValue ?? key
    }

    /// Get translated string with interpolation
    func t(_ key: String, args: [String: String]) -> String {
        var result = t(key)

        for (placeholder, value) in args {
            result = result.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }

        return result
    }
}

// MARK: - SwiftUI Extension

import SwiftUI

/// Convert a key or an English literal into a `LocalizedStringKey` using the app's JSON translations.
/// Works well with `Text`, `Button`, `Section`, `.navigationTitle(...)`, `.alert(...)`, etc.
func L(_ keyOrEnglishValue: String, defaultValue: String? = nil) -> LocalizedStringKey {
    LocalizedStringKey(LocalizationManager.shared.t(keyOrEnglishValue, defaultValue: defaultValue))
}

extension View {
    /// Apply localization to this view and all subviews
    func withLocalization() -> some View {
        self.environmentObject(LocalizationManager.shared)
    }
}

/// Localized Text view
struct LocalizedText: View {
    @EnvironmentObject var localization: LocalizationManager
    let key: String
    let defaultValue: String?
    let args: [String: String]?

    init(_ key: String, default: String? = nil, args: [String: String]? = nil) {
        self.key = key
        self.defaultValue = `default`
        self.args = args
    }

    var body: some View {
        if let args = args {
            Text(localization.t(key, args: args))
        } else {
            Text(localization.t(key, defaultValue: defaultValue))
        }
    }
}

/// String extension for easy localization
extension String {
    var localized: String {
        return LocalizationManager.shared.t(self)
    }

    func localized(with args: [String: String]) -> String {
        return LocalizationManager.shared.t(self, args: args)
    }
}

// MARK: - Reverse Lookup

private extension LocalizationManager {
    func englishValueToKey(_ englishValue: String) -> String? {
        reverseMapLock.lock()
        defer { reverseMapLock.unlock() }

        if !reverseEnglishValueToKey.isEmpty {
            return reverseEnglishValueToKey[englishValue]
        }

        // Build once from `en.json`.
        let en = loadTranslations(for: "en") ?? [:]
        var reverse: [String: String] = [:]
        for (k, v) in en {
            // If duplicates exist, keep the first for stability.
            if reverse[v] == nil {
                reverse[v] = k
            }
        }
        reverseEnglishValueToKey = reverse
        return reverseEnglishValueToKey[englishValue]
    }
}
