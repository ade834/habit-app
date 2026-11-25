import Foundation
import SwiftUI

// MARK: - Deterministic PRNG & Hashing (Spec Section 2)
enum GardenMath {
    /// 64-bit FNV-1a hash algorithm
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// SplitMix64 pseudo-random number generator
    struct SplitMix64PRNG {
        var state: UInt64

        init(seed: UInt64) {
            self.state = seed == 0 ? 0x9e3779b97f4a7c15 : seed
        }

        mutating func nextUInt64() -> UInt64 {
            state = state &+ 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }

        mutating func nextDouble() -> Double {
            Double(nextUInt64() & 0x001f_ffff_ffff_ffff) / Double(0x001f_ffff_ffff_ffff)
        }

        mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
            range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
        }

        mutating func nextInt(in range: ClosedRange<Int>) -> Int {
            guard range.upperBound >= range.lowerBound else { return range.lowerBound }
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int(nextUInt64() % span)
        }

        mutating func nextAngle(spread: Double) -> Double {
            nextDouble(in: -spread...spread)
        }
    }
}

// MARK: - Sampled Flower Traits (Sampled once per record and cached)
struct SampledFlowerTraits: Sendable {
    let seed: UInt64
    let petalCount: Int
    let petalLayers: Int
    let stemLeanAngle: Double // degrees
    let stemCurveFactor: Double // -1.0 ... 1.0
    let paletteIndex: Int
    let individualScale: Double
    let wobblePhase: Double
    let perPetalJitter: [PetalJitter]

    struct PetalJitter: Sendable {
        let lengthScale: Double
        let widthScale: Double
        let angleOffset: Double
        let tintVariation: Double
    }

    static func sample(from recipe: SpeciesRecipe, recordId: String) -> SampledFlowerTraits {
        let seed = GardenMath.fnv1a(recordId)
        var prng = GardenMath.SplitMix64PRNG(seed: seed)

        let petalCount = prng.nextInt(in: recipe.petalCount[0]...recipe.petalCount[1])
        let petalLayers = prng.nextInt(in: recipe.petalLayers[0]...recipe.petalLayers[1])
        let stemLean = prng.nextDouble(in: -14.0...14.0)
        let stemCurve = prng.nextDouble(in: -0.3...0.3)
        let paletteIndex = prng.nextInt(in: 0...max(0, recipe.palette.count - 1))
        let scaleJitter = prng.nextDouble(in: 0.94...1.06) * recipe.scale
        let wobblePhase = prng.nextDouble(in: 0...Double.pi * 2)

        var jitters: [PetalJitter] = []
        for _ in 0..<max(petalCount, 120) {
            jitters.append(PetalJitter(
                lengthScale: prng.nextDouble(in: 0.88...1.12),
                widthScale: prng.nextDouble(in: 0.88...1.12),
                angleOffset: prng.nextDouble(in: -0.08...0.08),
                tintVariation: prng.nextDouble(in: -0.06...0.06)
            ))
        }

        return SampledFlowerTraits(
            seed: seed,
            petalCount: petalCount,
            petalLayers: petalLayers,
            stemLeanAngle: stemLean,
            stemCurveFactor: stemCurve,
            paletteIndex: paletteIndex,
            individualScale: scaleJitter,
            wobblePhase: wobblePhase,
            perPetalJitter: jitters
        )
    }
}

// MARK: - Piecewise Stage Parameters (Spec Section 3)
struct BloomStageParams: Sendable {
    let stemHeightRatio: Double   // 0.0 ... 1.0
    let headScale: Double         // 0.0 ... 1.0
    let desaturation: Double      // 0.0 ... 1.0
    let droopAngle: Double        // degrees 0 ... 55
    let petalDropRatio: Double    // 0.0 ... 1.0
    let budWrapRatio: Double      // 1.0 when tight bud, 0.0 at full bloom
    let openRatio: Double         // 0.0 closed sprout, 0.55 half-open, 1.0 full bloom
    let foliageScale: Double      // 0.0 none, 0.4 young leaves, 0.75 lush, 1.0 full
    let sproutLeafSpread: Double  // 0.0 ... 1.0
    let soilDisturbance: Double   // 0.0 ... 1.0
    let particleBurstActive: Bool

    static func evaluate(renderLevel: Double) -> BloomStageParams {
        if renderLevel >= 2.0 {
            // Budding/Half-Bloom (2.0) -> Full Bloom (3.0)
            let t = min(max(renderLevel - 2.0, 0.0), 1.0)
            let stem = 0.72 + (1.00 - 0.72) * t
            let head = 0.65 + (1.00 - 0.65) * t
            let open = 0.55 + (1.00 - 0.55) * t
            let foliage = 0.75 + (1.00 - 0.75) * t
            let desat = 0.05 * (1.0 - t)
            let droop = 0.0
            let petalDrop = 0.0
            let budWrap = (1.0 - t) * 0.35
            return BloomStageParams(
                stemHeightRatio: stem,
                headScale: head,
                desaturation: desat,
                droopAngle: droop,
                petalDropRatio: petalDrop,
                budWrapRatio: budWrap,
                openRatio: open,
                foliageScale: foliage,
                sproutLeafSpread: 0.0,
                soilDisturbance: 0.0,
                particleBurstActive: t >= 0.85
            )
        } else if renderLevel >= 1.0 {
            // Sprouting (1.0) -> Budding/Half-Bloom (2.0)
            let t = renderLevel - 1.0
            let stem = 0.38 + (0.72 - 0.38) * t
            let head = 0.35 + (0.65 - 0.35) * t
            let open = 0.15 + (0.55 - 0.15) * t
            let foliage = 0.40 + (0.75 - 0.40) * t
            let desat = 0.0
            let droop = 0.0
            let petalDrop = 0.0
            let budWrap = 0.90 - 0.55 * t
            let sproutSpread = 1.0 - t
            return BloomStageParams(
                stemHeightRatio: stem,
                headScale: head,
                desaturation: desat,
                droopAngle: droop,
                petalDropRatio: petalDrop,
                budWrapRatio: budWrap,
                openRatio: open,
                foliageScale: foliage,
                sproutLeafSpread: sproutSpread,
                soilDisturbance: max(0.0, 0.45 - t * 0.45),
                particleBurstActive: false
            )
        } else if renderLevel >= 0.0 {
            // Seeded/Sprout (0.0) -> Sprouting (1.0)
            let t = renderLevel
            let stem = 0.12 + (0.38 - 0.12) * t
            let head = 0.18 + (0.35 - 0.18) * t
            let open = 0.00 + 0.15 * t
            let foliage = 0.00 + 0.40 * t
            let desat = 0.0
            let droop = 0.0
            let petalDrop = 0.0
            let budWrap = 1.0
            let sproutSpread = t
            let soil = 1.0 - t * 0.5
            return BloomStageParams(
                stemHeightRatio: stem,
                headScale: head,
                desaturation: desat,
                droopAngle: droop,
                petalDropRatio: petalDrop,
                budWrapRatio: budWrap,
                openRatio: open,
                foliageScale: foliage,
                sproutLeafSpread: sproutSpread,
                soilDisturbance: soil,
                particleBurstActive: false
            )
        } else if renderLevel >= -1.0 {
            // Wilting (-1.0) -> Seeded (0.0)
            let t = renderLevel + 1.0 // 0.0 at -1, 1.0 at 0
            let stem = 0.88 * (1.0 - t) + 0.12 * t
            let head = 0.78 * (1.0 - t)
            let open = 0.55 * (1.0 - t)
            let foliage = 0.50 * (1.0 - t)
            let desat = 0.45 * (1.0 - t)
            let droop = 28.0 * (1.0 - t)
            let petalDrop = 0.25 * (1.0 - t)
            return BloomStageParams(
                stemHeightRatio: stem,
                headScale: head,
                desaturation: desat,
                droopAngle: droop,
                petalDropRatio: petalDrop,
                budWrapRatio: 0.0,
                openRatio: open,
                foliageScale: foliage,
                sproutLeafSpread: 0.0,
                soilDisturbance: t * 0.8,
                particleBurstActive: false
            )
        } else if renderLevel >= -2.0 {
            // Faded (-2.0) -> Wilting (-1.0)
            let t = renderLevel + 2.0 // 0.0 at -2, 1.0 at -1
            let stem = 0.70 + (0.88 - 0.70) * t
            let head = 0.25 + (0.78 - 0.25) * t
            let open = 0.25 * t
            let foliage = 0.20 * t
            let desat = 0.80 - (0.80 - 0.45) * t
            let droop = 55.0 - (55.0 - 28.0) * t
            let petalDrop = 1.0 - (1.0 - 0.25) * t
            return BloomStageParams(
                stemHeightRatio: stem,
                headScale: head,
                desaturation: desat,
                droopAngle: droop,
                petalDropRatio: petalDrop,
                budWrapRatio: 0.0,
                openRatio: open,
                foliageScale: foliage,
                sproutLeafSpread: 0.0,
                soilDisturbance: 0.0,
                particleBurstActive: false
            )
        } else {
            // Gone (-3.0) -> Faded (-2.0)
            let t = min(max(renderLevel + 3.0, 0.0), 1.0) // 0.0 at -3, 1.0 at -2
            let stem = 0.70 * t
            let head = 0.25 * t
            let desat = 0.80 + 0.20 * (1.0 - t)
            let droop = 55.0 + 10.0 * (1.0 - t)
            return BloomStageParams(
                stemHeightRatio: stem,
                headScale: head,
                desaturation: desat,
                droopAngle: droop,
                petalDropRatio: 1.0,
                budWrapRatio: 0.0,
                openRatio: 0.0,
                foliageScale: 0.0,
                sproutLeafSpread: 0.0,
                soilDisturbance: 0.0,
                particleBurstActive: false
            )
        }
    }
}
