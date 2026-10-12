import Foundation

struct HabitCompletion: Sendable {
    let id: String
    let day: Date
}

/// Mirrors calculateGrowthSnapshot in the original Flutter domain layer.
enum HabitGrowthRules {
    static func progress(enabledAt: [String: Date], completions: [HabitCompletion], today: Date) -> [String: Int] {
        guard !enabledAt.isEmpty else { return [:] }
        let calendar = Calendar.current
        let todayDay = calendar.startOfDay(for: today)
        var values = Dictionary(uniqueKeysWithValues: enabledAt.keys.map { ($0, 0) })
        var eventsByDay: [Date: [HabitCompletion]] = [:]
        for event in completions {
            eventsByDay[calendar.startOfDay(for: event.day), default: []].append(event)
        }
        var cursor = enabledAt.values.map(calendar.startOfDay(for:)).min() ?? todayDay
        if let firstEvent = eventsByDay.keys.min(), firstEvent < cursor { cursor = firstEvent }
        var dormant = false
        var recovering = false
        var recoveryDays = 0
        var inactivityDays = 0
        var decayDay = 0
        var initialDay = true

        while cursor <= todayDay {
            let events = eventsByDay[cursor] ?? []
            for event in events where enabledAt[event.id] != nil {
                values[event.id, default: 0] += 1
            }
            if !events.isEmpty {
                inactivityDays = 0
                if dormant {
                    recovering = true
                    recoveryDays += 1
                    if recoveryDays >= 3 {
                        dormant = false
                        recovering = false
                        recoveryDays = 0
                        decayDay = 0
                    }
                }
            } else if cursor < todayDay && !initialDay {
                inactivityDays += 1
                if recovering && inactivityDays >= 7 {
                    recovering = false
                    recoveryDays = 0
                    dormant = true
                    decayDay = 0
                } else if !dormant && inactivityDays >= 7 {
                    dormant = true
                    decayDay = 0
                } else if dormant && !recovering {
                    decayDay += 1
                    let deduction = decayDay.isMultiple(of: 2) ? 2 : 1
                    for id in values.keys { values[id] = max(0, values[id, default: 0] - deduction) }
                }
            }
            initialDay = false
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return values
    }

    static func stage(for progress: Int) -> String {
        if progress >= 60 { return "繁茂" }
        if progress >= 25 { return "开花" }
        if progress >= 10 { return "成长" }
        if progress >= 3 { return "发芽" }
        return "种子"
    }
}
