import Foundation

@main struct Tests {
    static func main() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        let dates = ReminderDateRules.inactivityDates(lastCompletion: date(2026, 3, 6, 12), hour: 20, minute: 0, now: date(2026, 3, 6, 13), calendar: cal)
        precondition(dates == [date(2026, 3, 10, 20), date(2026, 3, 14, 20)])
        let afterThird = ReminderDateRules.inactivityDates(lastCompletion: date(2026, 3, 6), hour: 20, minute: 0, now: date(2026, 3, 11), calendar: cal)
        precondition(afterThird == [date(2026, 3, 14, 20)])
        precondition(ReminderDateRules.inactivityDates(lastCompletion: date(2026, 3, 6), hour: 20, minute: 0, now: date(2026, 3, 15), calendar: cal).isEmpty)
        let last = date(2026, 3, 6, 12)
        let completion = HabitCompletion(id: "H1", day: last)
        let decay = ReminderDateRules.firstGrowthDecrease(enabledAt: ["H1": last], completions: [completion], lastCompletion: last, calendar: cal)
        precondition(decay == date(2026, 3, 15))
        let plan = ReminderDateRules.plan(lastCompletion: last, decay: decay, hour: 20, minute: 0, now: last, inactivityEnabled: true, plantEnabled: true, calendar: cal)
        precondition(plan == [.init(date: date(2026, 3, 10, 20), kind: .inactivity), .init(date: date(2026, 3, 13, 20), kind: .plant), .init(date: date(2026, 3, 14, 20), kind: .inactivity)])
        let sameDay = ReminderDateRules.plan(lastCompletion: last, decay: decay, hour: 12, minute: 0, now: last, inactivityEnabled: true, plantEnabled: true, calendar: cal)
        precondition(sameDay == [.init(date: date(2026, 3, 10, 12), kind: .inactivity), .init(date: date(2026, 3, 14, 12), kind: .plant)])
        precondition(ReminderDateRules.plan(lastCompletion: last, decay: decay, hour: 20, minute: 0, now: date(2026, 3, 15), inactivityEnabled: true, plantEnabled: true, calendar: cal).isEmpty)
        let multiple = [completion, HabitCompletion(id: "H2", day: last)]
        precondition(ReminderDateRules.firstGrowthDecrease(enabledAt: ["H1": last, "H2": last], completions: multiple, lastCompletion: last, calendar: cal) == decay)
        precondition(ReminderDateRules.firstGrowthDecrease(enabledAt: ["H1": last], completions: [], lastCompletion: last, calendar: cal) == nil)
        let recovery = [completion, HabitCompletion(id: "H1", day: date(2026, 3, 16))]
        let recoveryDecay = ReminderDateRules.firstGrowthDecrease(enabledAt: ["H1": last], completions: recovery, lastCompletion: date(2026, 3, 16), calendar: cal)
        precondition(recoveryDecay == date(2026, 3, 25))
        let valueAfterLongGap = HabitGrowthRules.progress(enabledAt: ["H1": last], completions: [completion], today: date(2026, 4, 20), calendar: cal)
        precondition(valueAfterLongGap["H1"] == 0)
        let reset = ReminderDateRules.plan(lastCompletion: date(2026, 3, 10), decay: date(2026, 3, 19), hour: 20, minute: 0, now: date(2026, 3, 10, 19), inactivityEnabled: true, plantEnabled: true, calendar: cal)
        precondition(reset.allSatisfy { !cal.isDate($0.date, inSameDayAs: date(2026, 3, 10)) })
        var china = Calendar(identifier: .gregorian)
        china.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let chinaLast = china.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 10))!
        let chinaDates = ReminderDateRules.inactivityDates(lastCompletion: chinaLast, hour: 20, minute: 0, now: chinaLast, calendar: china)
        precondition(china.dateComponents([.year, .month, .day, .hour], from: chinaDates[0]) == DateComponents(year: 2027, month: 1, day: 4, hour: 20))
        print("ReminderDateRules tests passed")
    }
}
