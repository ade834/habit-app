import SwiftUI

@main
struct HabitNativeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appliedLanguage: String
    @State private var languageRefreshID = UUID()
    init() {
        AppSoundSettings.migrateLegacyPreference()
        // Theme selection belongs to Settings. A preview launch argument must not
        // shadow later writes from AppStorage for the lifetime of the process.
        let defaults = UserDefaults.standard
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments.removeValue(forKey: HabitColorTheme.storageKey)
        arguments.removeValue(forKey: AppLanguage.storageKey)
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        _appliedLanguage = State(initialValue: AppLanguage.current)
        ReminderManager.shared.start()
        SubscriptionManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    #if DEBUG
                    await DeviceValidationProbe.runIfRequested()
                    #endif
                    ReminderManager.shared.start()
                    SubscriptionManager.shared.start()
                    ICloudSyncManager.shared.requestSync(membership: SubscriptionManager.shared.currentTier)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        ReminderManager.shared.refresh()
                        ICloudSyncManager.shared.requestSync(membership: SubscriptionManager.shared.currentTier)
                    }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) } catch { return }
                        ICloudSyncManager.shared.requestSync(membership: SubscriptionManager.shared.currentTier)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: ReminderManager.dataChanged)) { _ in ReminderManager.shared.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: ICloudSyncManager.dataChanged)) { _ in ReminderManager.shared.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in ReminderManager.shared.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in ReminderManager.shared.refresh() }
                .id(languageRefreshID)
                .environment(\.locale, Locale(identifier: appliedLanguage))
                .onReceive(NotificationCenter.default.publisher(for: AppLanguage.didApply)) { notification in
                    guard let language = notification.object as? String else { return }
                    appliedLanguage = AppLanguage.resolve(language)
                    languageRefreshID = UUID()
                }
        }
    }
}
