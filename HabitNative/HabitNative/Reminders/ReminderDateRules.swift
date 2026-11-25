import Foundation

/// Dates are local calendar days. The completion day is day zero; only full
/// intervening days count as inactive, matching HabitGardenLiveSnapshot.
enum ReminderDateRules {
    enum Kind: Equatable { case inactivity, plant }
    struct Reminder: Equatable {
        let date: Date
        let kind: Kind
    }

    static func inactivityDates(lastCompletion: Date, hour: Int, minute: Int, now: Date, calendar: Calendar) -> [Date] {
        let completionDay = calendar.startOfDay(for: lastCompletion)
        return [3, 7].compactMap { days in
            guard let day = calendar.date(byAdding: .day, value: days + 1, to: completionDay),
                  let next = calendar.date(byAdding: .day, value: 1, to: day),
                  let time = calendar.nextDate(after: day.addingTimeInterval(-1), matching: DateComponents(hour: hour, minute: minute), matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward),
                  time < next, time > now else { return nil }
            return time
        }
    }

    /// Simulate the actual growth rules from the last completion, including
    /// recovery after dormancy. A first decrease starts a single care episode.
    static func firstGrowthDecrease(enabledAt: [String: Date], completions: [HabitCompletion], lastCompletion: Date, calendar: Calendar) -> Date? {
        let lastDay = calendar.startOfDay(for: lastCompletion)
        var previous = HabitGrowthRules.progress(enabledAt: enabledAt, completions: completions, today: lastDay, calendar: calendar)
        for offset in 1...16 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: lastDay) else { return nil }
            let current = HabitGrowthRules.progress(enabledAt: enabledAt, completions: completions, today: day, calendar: calendar)
            if current.contains(where: { $0.value < previous[$0.key, default: 0] }) { return day }
            previous = current
        }
        return nil
    }

    static func plan(lastCompletion: Date, decay: Date?, hour: Int, minute: Int, now: Date, inactivityEnabled: Bool, plantEnabled: Bool, calendar: Calendar) -> [Reminder] {
        var reminders = inactivityEnabled ? inactivityDates(lastCompletion: lastCompletion, hour: hour, minute: minute, now: now, calendar: calendar).map { Reminder(date: $0, kind: .inactivity) } : []
        if plantEnabled, let decay {
            let deadline = calendar.startOfDay(for: decay)
            let cutoff = deadline.addingTimeInterval(-6 * 60 * 60)
            let cutoffDay = calendar.startOfDay(for: cutoff)
            let candidate = calendar.nextDate(after: cutoffDay.addingTimeInterval(-1), matching: DateComponents(hour: hour, minute: minute), matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
            let time: Date? = candidate.flatMap { date in
                if date <= cutoff { return date }
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cutoffDay) else { return nil }
                return calendar.nextDate(after: previousDay.addingTimeInterval(-1), matching: DateComponents(hour: hour, minute: minute), matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
            }
            if let time, time <= cutoff, time > now,
               !calendar.isDate(time, inSameDayAs: lastCompletion) {
                reminders.removeAll { calendar.isDate($0.date, inSameDayAs: time) }
                reminders.append(Reminder(date: time, kind: .plant))
            }
        }
        return reminders.sorted { $0.date < $1.date }
    }
}
