import Foundation

/// The source catalog is bundled with the badge images and retains the user's
/// original unlock descriptions. Unlocks are evaluated separately.
struct BadgeDefinition: Decodable, Identifiable {
    let id: Int
    let name: String
    let requirement: String
    let motif: String

    var imageResourceName: String { String(format: "badge-%02d", id) }
}

enum BadgeCatalog {
    enum LoadError: Error {
        case missingCatalog
        case invalidCatalog
    }

    static func load(bundle: Bundle = .main) throws -> [BadgeDefinition] {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw LoadError.missingCatalog
        }
        let badges = try JSONDecoder().decode([BadgeDefinition].self, from: Data(contentsOf: url))
        guard badges.count == 50, Set(badges.map(\.id)) == Set(1...50) else {
            throw LoadError.invalidCatalog
        }
        return badges.sorted { $0.id < $1.id }
    }
}
