import Foundation

final class GardenRecipeRegistry: Sendable {
    static let shared = GardenRecipeRegistry()

    let recipes: [String: SpeciesRecipe]

    init() {
        let jsonString = """
        [
          { "id": "peony", "nameZh": "牡丹", "tier": "S", "archetype": "spiral-rose",
            "petalCount": [90, 140], "petalLayers": [5, 6], "petalShape": "broad-ruffled",
            "center": "dense-stamen", "palette": ["#C6235B", "#E91E63", "#F48FB1"],
            "scale": 1.15, "signature": "layerSequence", "foliage": "broad-leaf" },
          { "id": "rose", "nameZh": "月季", "tier": "S", "archetype": "spiral-rose",
            "petalCount": [60, 90], "petalLayers": [4, 5], "petalShape": "cupped-teardrop",
            "center": "spiral-eye", "palette": ["#8E1B2E", "#D8546E", "#F7EFE4"],
            "scale": 1.0, "signature": "glowEdge", "foliage": "compound-leaf" },
          { "id": "dahlia", "nameZh": "大丽花", "tier": "S", "archetype": "radial-multi",
            "petalCount": [100, 140], "petalLayers": [5, 6], "petalShape": "pointed-quill",
            "center": "tiny-disc", "palette": ["#7A0026", "#FF6B2B", "#6A1B9A"],
            "scale": 1.10, "signature": "geometricSymmetry", "foliage": "none" },
          { "id": "orchid", "nameZh": "兰花", "tier": "S", "archetype": "asymmetric-special",
            "petalCount": [6, 6], "petalLayers": [2, 2], "petalShape": "wing-and-lip",
            "center": "glowing-core", "palette": ["#BA68C8", "#F3E5F5", "#80CBC4"],
            "scale": 0.95, "signature": "glowingVeins", "foliage": "aerial-roots" },
          { "id": "lotus", "nameZh": "莲花", "tier": "S", "archetype": "radial-multi",
            "petalCount": [40, 70], "petalLayers": [4, 4], "petalShape": "pointed-long",
            "center": "pod-with-dust", "palette": ["#00B4D8", "#48CAE4", "#90E0EF"],
            "scale": 1.20, "signature": "goldDustCascade", "foliage": "round-leaf" },
          { "id": "iris", "nameZh": "鸢尾", "tier": "A", "archetype": "asymmetric-special",
            "petalCount": [6, 6], "petalLayers": [1, 1], "petalShape": "drooping-standard",
            "center": "gold-crest", "palette": ["#3949AB", "#8E24AA", "#FFD54F"],
            "scale": 1.00, "signature": "gradientFlow", "foliage": "sword-leaf" },
          { "id": "dandelion", "nameZh": "蒲公英", "tier": "A", "archetype": "orb-seedhead",
            "petalCount": [55, 65], "petalLayers": [1, 1], "petalShape": "filament-tuft",
            "center": "none", "palette": ["#2979FF", "#00B0FF", "#80D8FF"],
            "scale": 0.85, "signature": "filamentDisperse", "foliage": "toothed-leaf" },
          { "id": "poppy", "nameZh": "虞美人", "tier": "A", "archetype": "simple-bowl",
            "petalCount": [4, 6], "petalLayers": [1, 1], "petalShape": "paper-thin-ruffled",
            "center": "dark-stamen-ring", "palette": ["#D32F2F", "#FF5722", "#212121"],
            "scale": 1.00, "signature": "paperTremble", "foliage": "hairy-stem" },
          { "id": "sunflower", "nameZh": "向日葵", "tier": "A", "archetype": "disc-ray",
            "petalCount": [16, 24], "petalLayers": [1, 1], "petalShape": "long-oblong",
            "center": "fibonacci-disc", "palette": ["#FFB300", "#5D4037", "#FFA000"],
            "scale": 1.25, "signature": "fibonacciCenter", "foliage": "broad-leaf" },
          { "id": "daisy", "nameZh": "雏菊", "tier": "B", "archetype": "simple-bowl",
            "petalCount": [12, 20], "petalLayers": [1, 1], "petalShape": "slim-round",
            "center": "yellow-dot", "palette": ["#FFFFFF", "#F4D262"],
            "scale": 0.70, "signature": "looseSway", "foliage": "thin-stem" },
          { "id": "lily-of-valley", "nameZh": "铃兰", "tier": "B", "archetype": "bell-raceme",
            "petalCount": [6, 10], "petalLayers": [1, 1], "petalShape": "dangling-bell",
            "center": "none", "palette": ["#FAFAFA", "#E0E0E0", "#C8E6C9"],
            "scale": 0.65, "signature": "cascadingBells", "foliage": "broad-leaf" },
          { "id": "clover", "nameZh": "三叶草野花草", "tier": "B", "archetype": "cluster-wild",
            "petalCount": [5, 9], "petalLayers": [1, 1], "petalShape": "tiny-round",
            "center": "pale-yellow", "palette": ["#FFFFFF", "#F8BBD0", "#FFF9C4"],
            "scale": 0.55, "signature": "wildCluster", "foliage": "clover-twigs" }
        ]
        """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert recipe JSON to UTF-8 data")
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([SpeciesRecipe].self, from: data)
            var map: [String: SpeciesRecipe] = [:]
            for r in decoded {
                try r.validate()
                map[r.id] = r
            }
            self.recipes = map
        } catch {
            fatalError("Failed to validate garden recipe data: \(error)")
        }
    }

    func recipe(for speciesId: String) -> SpeciesRecipe {
        if let found = recipes[speciesId] {
            return found
        }
        // Fallback gracefully to rose if unknown
        return recipes["rose"] ?? recipes.values.first!
    }

    var allSpecies: [SpeciesRecipe] {
        Array(recipes.values).sorted { $0.tier.rawValue < $1.tier.rawValue }
    }
}
