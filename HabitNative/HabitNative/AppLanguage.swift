import Foundation

/// The stored override is independent of database values and user-entered text.
enum AppLanguage {
    static let storageKey = "app.language"
    static let didApply = Notification.Name("HabitNativeLanguageDidApply")

    static func resolve(_ preference: String, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if ["zh-Hans", "en-US", "ja"].contains(preference) { return preference }
        for candidate in preferredLanguages {
            if candidate.hasPrefix("zh") { return "zh-Hans" }
            if candidate.hasPrefix("ja") { return "ja" }
            if candidate.hasPrefix("en") { return "en-US" }
        }
        return "en-US"
    }

    static var current: String {
        #if DEBUG
        if DevelopmentLaunch.contains("--lang-zh") || CommandLine.arguments.contains(where: { $0 == "--lang-zh" || $0.contains("lang-zh") || $0.contains("AppleLanguages (zh") }) {
            return "zh-Hans"
        }
        if DevelopmentLaunch.contains("--lang-ja") || CommandLine.arguments.contains(where: { $0 == "--lang-ja" || $0.contains("lang-ja") || $0.contains("AppleLanguages (ja)") }) {
            return "ja"
        }
        if DevelopmentLaunch.contains("--lang-en") || CommandLine.arguments.contains(where: { $0 == "--lang-en" || $0.contains("lang-en") || $0.contains("AppleLanguages (en)") }) {
            return "en-US"
        }
        #endif
        return resolve(UserDefaults.standard.string(forKey: storageKey) ?? "system")
    }

    static var locale: Locale { Locale(identifier: current) }
    static func text(_ key: String) -> String {
        let code = current == "en-US" ? "en" : current
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func date(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
