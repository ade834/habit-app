import CoreFoundation
import Foundation

indirect enum SyncPreferenceValue: Codable, Equatable, Sendable {
    case string(String), integer(Int64), real(Double), boolean(Bool), date(Date), data(Data)
    case array([SyncPreferenceValue]), dictionary([String: SyncPreferenceValue])
}

struct SyncPreferenceItem: Codable, Equatable, Sendable {
    let key: String
    let value: SyncPreferenceValue
}

struct SyncRemotePreferenceChange: Sendable {
    let entityKey: String
    let data: Data?
}

/// Explicit allowlist: never copy Apple settings or per-device consent decisions.
enum SyncPreferenceReader {
    enum ReadError: Error { case unsupportedValue(String), invalidRemoteValue(String) }
    private static let exactKeys: Set<String> = [
        "app.language", "app.sound.effects.enabled", "appearance.colorTheme",
        "review.typewriter.night", "garden.plantPlacements", "garden_flower_positions_v1"
    ]
    private static let prefixes = ["review.typewriter.draft.", "review.ai.last-request."]

    private static func permits(_ key: String) -> Bool {
        exactKeys.contains(key) || prefixes.contains(where: { key.hasPrefix($0) && key.count > $0.count })
    }

    /// Validate the complete remote batch before it can be applied. A cloud
    /// payload may never write consent, credentials or an unrelated default.
    static func validatedRemoteChanges(_ changes: [SyncRemotePreferenceChange]) throws -> [(key: String, value: SyncPreferenceValue?)] {
        var seen = Set<String>()
        return try changes.map { change in
            let prefix = "preferences/"
            guard change.entityKey.hasPrefix(prefix) else { throw ReadError.invalidRemoteValue(change.entityKey) }
            let key = String(change.entityKey.dropFirst(prefix.count))
            guard permits(key), seen.insert(key).inserted else { throw ReadError.invalidRemoteValue(key) }
            guard let data = change.data else { return (key, nil) }
            guard let item = try? JSONDecoder().decode(SyncPreferenceItem.self, from: data), item.key == key,
                  valid(item.value), validType(item.value, for: key) else { throw ReadError.invalidRemoteValue(key) }
            return (key, item.value)
        }
    }

    private static func valid(_ value: SyncPreferenceValue, depth: Int = 0) -> Bool {
        guard depth <= 32 else { return false }
        switch value {
        case .real(let number): return number.isFinite
        case .date(let date): return date.timeIntervalSinceReferenceDate.isFinite
        case .array(let values): return values.allSatisfy { valid($0, depth: depth + 1) }
        case .dictionary(let values): return values.values.allSatisfy { valid($0, depth: depth + 1) }
        default: return true
        }
    }

    private static func validType(_ value: SyncPreferenceValue, for key: String) -> Bool {
        switch (key, value) {
        case ("app.language", .string), ("appearance.colorTheme", .string),
             ("app.sound.effects.enabled", .boolean), ("review.typewriter.night", .boolean),
             ("garden.plantPlacements", .data): return true
        case let (key, .date) where key.hasPrefix("review.ai.last-request."): return true
        case let (key, .dictionary(entries)) where key.hasPrefix("review.typewriter.draft."):
            return entries.values.allSatisfy { if case .string = $0 { return true }; return false }
        case ("garden_flower_positions_v1", .dictionary(let entries)):
            return entries.values.allSatisfy { value in
                guard case .array(let coordinates) = value, coordinates.count == 2 else { return false }
                return coordinates.allSatisfy { if case .real = $0 { return true }; if case .integer = $0 { return true }; return false }
            }
        default: return false
        }
    }

    static func read(_ defaults: UserDefaults) throws -> [SyncPreferenceItem] {
        try defaults.dictionaryRepresentation().keys.sorted().compactMap { key in
            guard permits(key), let value = defaults.object(forKey: key) else { return nil }
            return SyncPreferenceItem(key: key, value: try convert(value, key: key))
        }
    }

    private static func convert(_ value: Any, key: String) throws -> SyncPreferenceValue {
        if let value = value as? String { return .string(value) }
        if let value = value as? Data { return .data(value) }
        if let value = value as? Date { return .date(value) }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return .boolean(value.boolValue) }
            if ["f", "d"].contains(String(cString: value.objCType)) {
                guard value.doubleValue.isFinite else { throw ReadError.unsupportedValue(key) }
                return .real(value.doubleValue)
            }
            return .integer(value.int64Value)
        }
        if let value = value as? [Any] { return .array(try value.map { try convert($0, key: key) }) }
        if let value = value as? [String: Any] { return .dictionary(try value.mapValues { try convert($0, key: key) }) }
        throw ReadError.unsupportedValue(key)
    }
}
