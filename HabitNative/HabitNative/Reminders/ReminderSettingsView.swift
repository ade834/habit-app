import SwiftUI
import UserNotifications
import UIKit

struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("reminder.minutes") private var minutes = 1200
    @AppStorage("reminder.inactivity") private var inactivity = false
    @AppStorage("reminder.plant") private var plant = false
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    private var time: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
            ReminderManager.shared.refresh()
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(AppLanguage.text("reminder.time"), selection: time, displayedComponents: .hourAndMinute)
                    Toggle(AppLanguage.text("reminder.inactivity.toggle"), isOn: preference($inactivity))
                    Toggle(AppLanguage.text("reminder.plant.toggle"), isOn: preference($plant))
                } footer: {
                    Text(AppLanguage.text("reminder.explanation"))
                }
                Section {
                    if authorization == .denied {
                        Text(AppLanguage.text("reminder.disabled"))
                    }
                    Button(AppLanguage.text("reminder.settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
            .navigationTitle(AppLanguage.text("reminder.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(AppLanguage.text("reminder.done")) { dismiss() } } }
            .task { await updateAuthorization() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await updateAuthorization(); ReminderManager.shared.refresh() } }
            }
        }
    }
    private func preference(_ value: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue }, set: { enabled in
            value.wrappedValue = enabled
            Task {
                let center = UNUserNotificationCenter.current()
                let current = await center.notificationSettings().authorizationStatus
                if enabled && current == .notDetermined {
                    _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                }
                await updateAuthorization()
                ReminderManager.shared.refresh()
            }
        })
    }
    private func updateAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
