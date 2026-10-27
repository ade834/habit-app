import SwiftUI

@main
struct HabitNativeApp: App {
    init() {
        AppSoundSettings.migrateLegacyPreference()
        // Theme selection belongs to Settings. A preview launch argument must not
        // shadow later writes from AppStorage for the lifetime of the process.
        let defaults = UserDefaults.standard
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments.removeValue(forKey: HabitColorTheme.storageKey)
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
