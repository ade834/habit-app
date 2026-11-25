import Foundation
import SwiftUI

// MARK: - BloomRecord (The one rule everything rests on)
/// Database supplies identity, species, integer level (-3...3) and normalized position.
struct BloomRecord: Identifiable, Hashable, Codable, Sendable {
    let id: String        // stable seed & diff key (e.g. habit ID "H1")
    var species: String   // recipe key (e.g. "peony", "rose")
    var level: Int        // -3 ... 3
    var position: CGPoint // normalized 0...1 in stage area; stem base

    init(id: String, species: String, level: Int, position: CGPoint) {
        self.id = id
        self.species = species
        self.level = min(max(level, -3), 3)
        self.position = position
    }
}

// MARK: - Rarity Tiers
enum FlowerTier: String, Codable, Sendable {
    case s = "S" // 华丽: multi-layer, glowing petal edges, particle burst, secondary blooms
    case a = "A" // 特别: one strong signature trait
    case b = "B" // 自然: relaxed sway, companion foliage, grass/twigs

    var displayName: String {
        switch self {
        case .s: return "S · 华丽"
        case .a: return "A · 特别"
        case .b: return "B · 自然"
        }
    }

    var weight: Double {
        switch self {
        case .s: return 3.0
        case .a: return 2.0
        case .b: return 1.0
        }
    }
}

// MARK: - Head Archetypes
enum BloomArchetype: String, Codable, Sendable {
    case spiralRose = "spiral-rose"
    case radialMulti = "radial-multi"
    case asymmetricSpecial = "asymmetric-special"
    case orbSeedhead = "orb-seedhead"
    case simpleBowl = "simple-bowl"
    case discRay = "disc-ray"
    case bellRaceme = "bell-raceme"
    case clusterWild = "cluster-wild"
}

// MARK: - Species Recipe
struct SpeciesRecipe: Identifiable, Codable, Sendable {
    let id: String
    let nameZh: String
    let tier: FlowerTier
    let archetype: BloomArchetype
    let petalCount: [Int] // [min, max]
    let petalLayers: [Int] // [min, max]
    let petalShape: String
    let center: String
    let palette: [String] // Hex color strings
    let scale: Double
    let signature: String
    let foliage: String

    func validate() throws {
        guard petalCount.count >= 2, petalCount[0] <= petalCount[1], petalCount[0] >= 0 else {
            throw RecipeValidationError.invalidPetalCount(id: id, count: petalCount)
        }
        guard petalLayers.count >= 2, petalLayers[0] <= petalLayers[1], petalLayers[0] >= 1 else {
            throw RecipeValidationError.invalidPetalLayers(id: id, layers: petalLayers)
        }
        guard !palette.isEmpty else {
            throw RecipeValidationError.emptyPalette(id: id)
        }
        guard scale > 0.1 && scale <= 3.0 else {
            throw RecipeValidationError.invalidScale(id: id, scale: scale)
        }
    }
}

enum RecipeValidationError: LocalizedError {
    case invalidPetalCount(id: String, count: [Int])
    case invalidPetalLayers(id: String, layers: [Int])
    case emptyPalette(id: String)
    case invalidScale(id: String, scale: Double)
    case unknownSpecies(String)

    var errorDescription: String? {
        switch self {
        case .invalidPetalCount(let id, let c): return "Species [\(id)] has invalid petalCount: \(c)"
        case .invalidPetalLayers(let id, let l): return "Species [\(id)] has invalid petalLayers: \(l)"
        case .emptyPalette(let id): return "Species [\(id)] has empty palette"
        case .invalidScale(let id, let s): return "Species [\(id)] has invalid scale: \(s)"
        case .unknownSpecies(let id): return "Unknown species recipe: \(id)"
        }
    }
}

// MARK: - Seven Garden Levels
enum GardenStageLevel: Int, CaseIterable, Comparable, Sendable {
    case gone = -3       // 消失: no flower drawn, position preserved
    case faded = -2      // 凋谢: petals gone, dry stem drooping 55°
    case wilting = -1    // 枯萎: desaturated 45%, drooping 28°, 1-2 petals fall
    case seeded = 0      // 埋种: small soil mound, shoot tip
    case sprouting = 1   // 发芽: 30% stem, two seed leaves
    case budding = 2     // 花苞: 70% stem, bud casing wrapped, breathing pulse
    case blooming = 3    // 开花: 100% full bloom, glowing edges, particles

    static func < (lhs: GardenStageLevel, rhs: GardenStageLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var titleZh: String {
        switch self {
        case .blooming: return "开花 Blooming"
        case .budding: return "花苞 Budding"
        case .sprouting: return "发芽 Sprouting"
        case .seeded: return "埋种 Seeded"
        case .wilting: return "枯萎 Wilting"
        case .faded: return "凋谢 Faded"
        case .gone: return "休眠 Gone"
        }
    }

    var attractionWeight: Double {
        switch self {
        case .blooming: return 1.0
        case .budding: return 0.3
        case .sprouting, .seeded: return 0.0
        case .wilting: return 0.15
        case .faded, .gone: return 0.0
        }
    }
}
