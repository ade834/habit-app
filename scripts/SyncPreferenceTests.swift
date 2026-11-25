import Foundation

@main struct SyncPreferenceTests {
    static func main() throws {
        let suite = "SyncPreferenceTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["decision": "私人文字"], forKey: "review.typewriter.draft.H1.100")
        defaults.set(Date(timeIntervalSince1970: 123), forKey: "review.ai.last-request.week.2026-10-26")
        defaults.set(Data([1, 2, 3]), forKey: "garden.plantPlacements")
        defaults.set(true, forKey: "app.sound.effects.enabled")
        defaults.set(true, forKey: "review.ai.privacy-consent.v3")
        defaults.set("do not sync", forKey: "unknown.private.key")
        let items = try SyncPreferenceReader.read(defaults)
        let byKey = Dictionary(uniqueKeysWithValues: items.map { ($0.key, $0.value) })
        precondition(byKey["review.typewriter.draft.H1.100"] == .dictionary(["decision": .string("私人文字")]))
        precondition(byKey["review.ai.last-request.week.2026-10-26"] == .date(Date(timeIntervalSince1970: 123)))
        precondition(byKey["garden.plantPlacements"] == .data(Data([1, 2, 3])))
        precondition(byKey["app.sound.effects.enabled"] == .boolean(true))
        precondition(byKey["review.ai.privacy-consent.v3"] == nil && byKey["unknown.private.key"] == nil)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(items)
        let decoded = try JSONDecoder().decode([SyncPreferenceItem].self, from: encoded)
        precondition(decoded == items)
        print("PASS: drafts, cooldown, garden settings and consent isolation")
    }
}
