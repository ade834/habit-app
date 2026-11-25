import Foundation
import SQLite3
import UserNotifications
import UIKit

@MainActor
final class ReminderManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderManager()
    static let dataChanged = Notification.Name("HabitReminderDataChanged")
    static let openDestination = Notification.Name("HabitReminderOpenDestination")
    private let center = UNUserNotificationCenter.current()
    private let prefix = "habit.reminder.v1."
    private var generation = 0
    private var refreshing = false

    override init() { super.init() }

    func start() {
        center.delegate = self
        refresh()
    }

    func refresh() {
        generation += 1
        guard !refreshing else { return }
        refreshing = true
        Task {
            repeat {
                let revision = generation
                await reconcile(revision: revision)
                if revision == generation { break }
            } while true
            refreshing = false
        }
    }

    private func reconcile(revision: Int) async {
            let settings = await center.notificationSettings()
            guard revision == generation else { return }
            let pending = await center.pendingNotificationRequests()
            guard revision == generation else { return }
            let defaults = UserDefaults.standard
            let now = Date()
            // Retain past scheduled deliveries even if the user removed them
            // from Notification Center. This prevents another alert that day.
            var history = (defaults.dictionary(forKey: "reminder.history") as? [String: Double] ?? [:]).filter { $0.value <= now.timeIntervalSince1970 && $0.value > now.addingTimeInterval(-45 * 86400).timeIntervalSince1970 }
            for request in pending where request.identifier.hasPrefix(prefix) {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger, let date = trigger.nextTriggerDate(), date <= now {
                    history[request.identifier] = date.timeIntervalSince1970
                }
            }
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            defaults.set(history, forKey: "reminder.history")
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let inactivity = defaults.bool(forKey: "reminder.inactivity")
            let plant = defaults.bool(forKey: "reminder.plant")
            guard inactivity || plant, let data = try? readData(), let last = data.completions.map(\.day).max() else { return }
            let minutes = defaults.object(forKey: "reminder.minutes") == nil ? 1200 : defaults.integer(forKey: "reminder.minutes")
            let calendar = Calendar.current
            let decay = ReminderDateRules.firstGrowthDecrease(enabledAt: data.enabledAt, completions: data.completions, lastCompletion: last, calendar: calendar)
            let plans = ReminderDateRules.plan(lastCompletion: last, decay: decay, hour: minutes / 60, minute: minutes % 60, now: now, inactivityEnabled: inactivity, plantEnabled: plant, calendar: calendar)
            let delivered = await center.deliveredNotifications()
            guard revision == generation else { return }
            let cycle = calendar.dateComponents([.year, .month, .day], from: last)
            let cycleID = "\(cycle.year ?? 0)-\(cycle.month ?? 0)-\(cycle.day ?? 0)"
            let deliveredIDs = Set(delivered.map { $0.request.identifier })
            for notification in delivered where notification.request.identifier.hasPrefix(prefix) {
                history[notification.request.identifier] = notification.date.timeIntervalSince1970
            }
            for plan in plans {
                let kind = plan.kind == .plant ? "plant" : "inactivity"
                let day = calendar.dateComponents([.year, .month, .day], from: plan.date)
                let id = "\(prefix)\(kind).\(cycleID).\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
                let alreadySentToday = history.values.contains { calendar.isDate(Date(timeIntervalSince1970: $0), inSameDayAs: plan.date) }
                let plantSentInCycle = kind == "plant" && history.keys.contains { $0.hasPrefix("\(prefix)plant.\(cycleID).") }
                guard !deliveredIDs.contains(id), !alreadySentToday, !plantSentInCycle, revision == generation else { continue }
                let content = UNMutableNotificationContent()
                content.title = AppLanguage.text(kind == "plant" ? "reminder.plant.title" : "reminder.inactivity.title")
                var variants = defaults.dictionary(forKey: "reminder.textVariants") as? [String: Int] ?? [:]
                let variant = variants[id] ?? Int.random(in: 0..<(kind == "plant" ? 8 : 4))
                variants[id] = variant
                defaults.set(variants, forKey: "reminder.textVariants")
                content.body = AppLanguage.text("reminder.\(kind).body.\(variant)")
                content.sound = .default
                content.userInfo = ["destination": kind]
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.date)
                components.timeZone = calendar.timeZone
                let request = UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                do {
                    try await center.add(request)
                    history[id] = plan.date.timeIntervalSince1970
                    defaults.set(history, forKey: "reminder.history")
                } catch { continue }
            }
    }

    private func readData() throws -> (enabledAt: [String: Date], completions: [HabitCompletion]) {
        try NativeDatabase().withConnection { db in
            try NativeDatabase.execute("BEGIN DEFERRED", in: db)
            defer { try? NativeDatabase.execute("ROLLBACK", in: db) }
            var enabled: [String: Date] = [:]
            let selections = try NativeDatabase.prepare("SELECT habit_id, enabled_at FROM habit_selections", in: db)
            defer { sqlite3_finalize(selections) }
            while sqlite3_step(selections) == SQLITE_ROW {
                guard let raw = sqlite3_column_text(selections, 0) else { continue }
                enabled[String(cString: raw)] = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(selections, 1)))
            }
            let logs = try NativeDatabase.prepare("SELECT habit_id, local_date FROM habit_logs", in: db)
            defer { sqlite3_finalize(logs) }
            var completions: [HabitCompletion] = []
            while sqlite3_step(logs) == SQLITE_ROW {
                guard let id = sqlite3_column_text(logs, 0), let raw = sqlite3_column_text(logs, 1) else { continue }
                let parts = String(cString: raw).split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3, let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { continue }
                completions.append(HabitCompletion(id: String(cString: id), day: date))
            }
            return (enabled, completions)
        }
    }

    func hasExactlyOneCompletion() -> Bool {
        guard let data = try? readData() else { return false }
        return data.completions.count == 1
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let destination = response.notification.request.content.userInfo["destination"] as? String
        Task { @MainActor in
            UserDefaults.standard.set(destination, forKey: "reminder.destination")
            NotificationCenter.default.post(name: Self.openDestination, object: destination)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
