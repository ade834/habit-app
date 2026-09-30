import SwiftUI

// MARK: - Color Palette Helpers (Lighten, Darken, Saturate, Desaturate)
extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func desaturated(by amount: Double) -> Color {
        guard amount > 0.01 else { return self }
        // Blend towards neutral warm gray
        let gray = Color(red: 0.58, green: 0.54, blue: 0.50)
        return self.opacity(1.0 - amount * 0.7)
    }

    func adjustedForWilt(desaturation: Double) -> Color {
        if desaturation <= 0.05 {
            return self
        }
        // Tint towards dry withered flora tone
        let dryTone = Color(red: 0.55, green: 0.48, blue: 0.38)
        let t = min(desaturation, 1.0)
        return self.opacity(1.0 - t * 0.5)
    }
}

// MARK: - Procedural Flower View
struct FlowerProceduralView: View {
    let record: BloomRecord
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let renderLevel: Double
    let windAngle: Double // sway offset in radians
    let breathingPhase: Double
    let isDissolving: Bool

    init(
        record: BloomRecord,
        recipe: SpeciesRecipe,
        traits: SampledFlowerTraits,
        renderLevel: Double,
        windAngle: Double = 0,
        breathingPhase: Double = 0,
        isDissolving: Bool = false
    ) {
        self.record = record
        self.recipe = recipe
        self.traits = traits
        self.renderLevel = renderLevel
        self.windAngle = windAngle
        self.breathingPhase = breathingPhase
        self.isDissolving = isDissolving
    }

    private var params: BloomStageParams {
        BloomStageParams.evaluate(renderLevel: renderLevel)
    }

    private var customStemColor: Color {
        switch recipe.id {
        case "dandelion":
            return Color(red: 0.10, green: 0.34, blue: 0.48) // deep teal-navy
        case "rose", "poppy":
            return Color(red: 0.52, green: 0.20, blue: 0.28) // crimson stalk
        case "lotus":
            return Color(red: 0.62, green: 0.26, blue: 0.36) // coral-carmine stalk
        case "peony":
            return Color(red: 0.20, green: 0.48, blue: 0.32) // deep emerald stalk
        case "iris":
            return Color(red: 0.25, green: 0.28, blue: 0.50) // indigo stalk
        default:
            return Color(red: 0.28, green: 0.52, blue: 0.36) // botanical green
        }
    }

    var body: some View {
        let baseHeight: CGFloat = 210 * CGFloat(traits.individualScale)
        let stemHeight = max(baseHeight * CGFloat(params.stemHeightRatio), 10)
        let primaryColor = Color(hexString: recipe.palette[traits.paletteIndex % recipe.palette.count])
        let secondaryColor = Color(hexString: recipe.palette[(traits.paletteIndex + 1) % recipe.palette.count])

        ZStack(alignment: .bottom) {
            if renderLevel <= -2.8 && !isDissolving {
                // Dormant / gone: just slight ground marker
                Circle()
                    .fill(Color(red: 0.65, green: 0.55, blue: 0.48).opacity(0.22))
                    .frame(width: 14, height: 6)
            } else if isDissolving {
                // Dissolving particles on 0 <-> -1 boundary
                DissolveBurstView(color: primaryColor)
                    .frame(width: 60, height: 60)
            } else {
                // 1. Soil Mound (Seeded / Sprouting)
                if params.soilDisturbance > 0.05 {
                    SoilMoundShape()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.45, green: 0.38, blue: 0.32), Color(red: 0.35, green: 0.28, blue: 0.24)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 28 * CGFloat(params.soilDisturbance), height: 10 * CGFloat(params.soilDisturbance))
                        .offset(y: 4)
                }

                // 2. Stem
                if params.stemHeightRatio > 0.05 {
                    ProceduralStemView(
                        stemHeight: stemHeight,
                        leanAngle: traits.stemLeanAngle + windAngle * 10,
                        curveFactor: traits.stemCurveFactor,
                        droopAngle: params.droopAngle,
                        desaturation: params.desaturation,
                        hasSprigs: recipe.foliage != "none",
                        stemBaseColor: customStemColor
                    )
                }

                // 3. Sprout twin leaves (Level 1)
                if params.sproutLeafSpread > 0.05 && renderLevel < 1.9 {
                    SproutTwinLeaves(spread: params.sproutLeafSpread)
                        .offset(y: -stemHeight)
                }

                // 4. Bud or Bloom Head (Level 2 & 3 & wilting)
                if params.headScale > 0.05 && renderLevel >= 1.2 {
                    Group {
                        if params.budWrapRatio > 0.3 {
                            // Bud Casing
                            BudCasingView(
                                scale: params.headScale * (1.0 + sin(breathingPhase) * 0.05),
                                primaryColor: primaryColor,
                                budWrap: params.budWrapRatio
                            )
                        } else {
                            // Full Procedural Bloom Head
                            ProceduralBloomHeadView(
                                recipe: recipe,
                                traits: traits,
                                primaryColor: primaryColor,
                                secondaryColor: secondaryColor,
                                scale: params.headScale,
                                desaturation: params.desaturation,
                                droopAngle: params.droopAngle,
                                petalDropRatio: params.petalDropRatio
                            )
                        }
                    }
                    .offset(y: -stemHeight)
                    .rotationEffect(.degrees(params.droopAngle), anchor: .bottom)
                }
            }
        }
        .frame(width: 140, height: baseHeight + 50, alignment: .bottom)
    }
}

// MARK: - Procedural Stem
private struct ProceduralStemView: View {
    let stemHeight: CGFloat
    let leanAngle: Double
    let curveFactor: Double
    let droopAngle: Double
    let desaturation: Double
    let hasSprigs: Bool
    var stemBaseColor: Color = Color(red: 0.28, green: 0.52, blue: 0.36)

    var body: some View {
        Canvas { context, size in
            let start = CGPoint(x: size.width / 2, y: size.height)
            let leanRad = (leanAngle * .pi) / 180.0
            let targetX = start.x + sin(leanRad) * stemHeight
            let targetY = start.y - cos(leanRad) * stemHeight
            let end = CGPoint(x: targetX, y: targetY)

            // Cubic Bézier control points
            let cp1 = CGPoint(
                x: start.x + CGFloat(curveFactor * 25),
                y: start.y - stemHeight * 0.45
            )
            let cp2 = CGPoint(
                x: targetX - CGFloat(curveFactor * 18),
                y: start.y - stemHeight * 0.75
            )

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: cp1, control2: cp2)

            let stemColor = desaturation > 0.3
                ? Color(red: 0.48, green: 0.46, blue: 0.38)
                : stemBaseColor

            let lineWidth: CGFloat = max(1.8, min(3.4, stemHeight * 0.016))
            context.stroke(path, with: .color(stemColor), lineWidth: lineWidth)

            // Leaf sprig along stem
            if hasSprigs && stemHeight > 50 {
                let leafY = start.y - stemHeight * 0.45
                let leafX = (cp1.x + cp2.x) / 2
                var leaf = Path()
                leaf.move(to: CGPoint(x: leafX, y: leafY))
                leaf.addQuadCurve(
                    to: CGPoint(x: leafX + 16, y: leafY - 8),
                    control: CGPoint(x: leafX + 10, y: leafY - 14)
                )
                leaf.addQuadCurve(
                    to: CGPoint(x: leafX, y: leafY),
                    control: CGPoint(x: leafX + 6, y: leafY - 2)
                )
                context.fill(leaf, with: .color(stemColor.opacity(0.85)))
            }
        }
        .frame(height: stemHeight + 10)
    }
}

// MARK: - Soil Mound
private struct SoilMoundShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Sprout Twin Leaves
private struct SproutTwinLeaves: View {
    let spread: Double

    var body: some View {
        HStack(spacing: 2) {
            // Left cotyledon
            Capsule()
                .fill(Color(red: 0.42, green: 0.72, blue: 0.46))
                .frame(width: 8, height: 14)
                .rotationEffect(.degrees(-35 * spread), anchor: .bottomTrailing)
            // Right cotyledon
            Capsule()
                .fill(Color(red: 0.36, green: 0.68, blue: 0.40))
                .frame(width: 8, height: 14)
                .rotationEffect(.degrees(35 * spread), anchor: .bottomLeading)
        }
    }
}

// MARK: - Bud Casing View
private struct BudCasingView: View {
    let scale: Double
    let primaryColor: Color
    let budWrap: Double

    var body: some View {
        ZStack {
            // Peeking petal tip
            Circle()
                .fill(primaryColor.opacity(0.85))
                .frame(width: 14, height: 16)
                .offset(y: -4)

            // Green enclosing sepals
            HStack(spacing: -3) {
                Capsule()
                    .fill(Color(red: 0.32, green: 0.58, blue: 0.38))
                    .frame(width: 11, height: 22)
                    .rotationEffect(.degrees(-15))
                Capsule()
                    .fill(Color(red: 0.28, green: 0.52, blue: 0.34))
                    .frame(width: 11, height: 22)
                    .rotationEffect(.degrees(15))
            }
        }
        .scaleEffect(CGFloat(scale))
    }
}

// MARK: - Procedural Bloom Head Dispatcher
private struct ProceduralBloomHeadView: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let scale: Double
    let desaturation: Double
    let droopAngle: Double
    let petalDropRatio: Double

    var body: some View {
        Group {
            switch recipe.archetype {
            case .spiralRose:
                SpiralRoseHead(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    desaturation: desaturation,
                    petalDropRatio: petalDropRatio
                )
            case .radialMulti:
                RadialMultiHead(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    desaturation: desaturation,
                    petalDropRatio: petalDropRatio
                )
            case .asymmetricSpecial:
                AsymmetricSpecialHead(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    desaturation: desaturation
                )
            case .orbSeedhead:
                OrbSeedheadDandelion(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    desaturation: desaturation,
                    petalDropRatio: petalDropRatio
                )
            case .simpleBowl:
                SimpleBowlHead(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    desaturation: desaturation,
                    petalDropRatio: petalDropRatio
                )
            case .discRay:
                DiscRaySunflower(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    desaturation: desaturation
                )
            case .bellRaceme:
                BellRacemeLily(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    desaturation: desaturation
                )
            case .clusterWild:
                ClusterWildClover(
                    recipe: recipe,
                    traits: traits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    desaturation: desaturation
                )
            }
        }
        .scaleEffect(CGFloat(scale))
    }
}

// MARK: - 1. Spiral Rose Head (Peony, Rose)
private struct SpiralRoseHead: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let desaturation: Double
    let petalDropRatio: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let totalLayers = traits.petalLayers
            let totalPetals = traits.petalCount
            let goldenAngle = 137.507764 * Double.pi / 180.0

            let activePetals = max(0, Int(Double(totalPetals) * (1.0 - petalDropRatio)))
            let petalsPerLayer = max(1, activePetals / totalLayers)

            for layer in (0..<totalLayers).reversed() {
                let layerProgress = Double(layer) / Double(max(1, totalLayers - 1))
                let layerRadius = 14.0 + layerProgress * 26.0

                for i in 0..<petalsPerLayer {
                    let index = layer * petalsPerLayer + i
                    guard index < traits.perPetalJitter.count else { continue }
                    let jitter = traits.perPetalJitter[index]
                    let angle = Double(index) * goldenAngle + jitter.angleOffset

                    let petalW = (18.0 + layerProgress * 12.0) * jitter.widthScale
                    let petalH = (22.0 + layerProgress * 16.0) * jitter.lengthScale

                    let x = center.x + cos(angle) * (layerRadius * 0.4)
                    let y = center.y + sin(angle) * (layerRadius * 0.4)

                    var petalPath = Path()
                    petalPath.addEllipse(in: CGRect(x: -petalW / 2, y: -petalH, width: petalW, height: petalH))

                    var petalTransform = CGAffineTransform(translationX: x, y: y)
                        .rotated(by: CGFloat(angle + Double.pi / 2))

                    let transformed = petalPath.applying(petalTransform)

                    let color = (index % 2 == 0 ? primaryColor : secondaryColor)
                        .opacity(0.88 - layerProgress * 0.2)
                    let finalColor = color.adjustedForWilt(desaturation: desaturation)

                    context.fill(transformed, with: .color(finalColor))

                    // Glowing edge for Tier S
                    if recipe.tier == .s && layer == totalLayers - 1 {
                        context.stroke(transformed, with: .color(.white.opacity(0.4)), lineWidth: 0.8)
                    }
                }
            }

            // Core
            var core = Path()
            core.addEllipse(in: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
            context.fill(core, with: .color(Color(red: 0.98, green: 0.84, blue: 0.35)))
        }
        .frame(width: 90, height: 90)
    }
}

// MARK: - 2. Radial Multi Head (Dahlia, Lotus)
private struct RadialMultiHead: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let desaturation: Double
    let petalDropRatio: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let petals = max(8, Int(Double(traits.petalCount) * (1.0 - petalDropRatio)))
            let step = (Double.pi * 2) / Double(petals)

            for i in 0..<petals {
                let angle = Double(i) * step
                let petalLen: CGFloat = 34
                let petalWidth: CGFloat = 11

                var path = Path()
                path.move(to: .zero)
                path.addQuadCurve(to: CGPoint(x: 0, y: -petalLen), control: CGPoint(x: -petalWidth, y: -petalLen * 0.6))
                path.addQuadCurve(to: .zero, control: CGPoint(x: petalWidth, y: -petalLen * 0.6))

                let transform = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: CGFloat(angle))
                let transformed = path.applying(transform)

                let color = (i % 2 == 0 ? primaryColor : secondaryColor)
                    .adjustedForWilt(desaturation: desaturation)
                context.fill(transformed, with: .color(color.opacity(0.85)))
            }

            // Central seedpod
            var pod = Path()
            pod.addEllipse(in: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18))
            context.fill(pod, with: .color(Color(red: 0.96, green: 0.82, blue: 0.42)))
        }
        .frame(width: 96, height: 96)
    }
}

// MARK: - 3. Asymmetric Special Head (Orchid, Iris)
private struct AsymmetricSpecialHead: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let desaturation: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Winged upper petals
            for angle in [-0.55, 0.55] {
                var wing = Path()
                wing.addEllipse(in: CGRect(x: -16, y: -38, width: 32, height: 42))
                let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(angle))
                context.fill(wing.applying(transform), with: .color(primaryColor.opacity(0.85).adjustedForWilt(desaturation: desaturation)))
            }

            // Side lateral petals
            for angle in [-1.57, 1.57] {
                var petal = Path()
                petal.addEllipse(in: CGRect(x: -10, y: -30, width: 20, height: 32))
                let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(angle))
                context.fill(petal.applying(transform), with: .color(secondaryColor.opacity(0.75).adjustedForWilt(desaturation: desaturation)))
            }

            // Prominent lower lip
            var lip = Path()
            lip.addEllipse(in: CGRect(x: center.x - 14, y: center.y - 2, width: 28, height: 26))
            context.fill(lip, with: .color(Color(red: 0.88, green: 0.28, blue: 0.54).adjustedForWilt(desaturation: desaturation)))

            // Glowing core
            var core = Path()
            core.addEllipse(in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
            context.fill(core, with: .color(.white))
            context.stroke(core, with: .color(Color(red: 0.98, green: 0.84, blue: 0.35)), lineWidth: 1.5)
        }
        .frame(width: 88, height: 88)
    }
}

// MARK: - 4. Orb Seedhead (Dandelion 蒲公英) - Matches user POSY photo!
private struct OrbSeedheadDandelion: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let desaturation: Double
    let petalDropRatio: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let totalFilaments = max(36, Int(Double(traits.petalCount) * (1.0 - petalDropRatio)))
            let goldenAngle = 137.507764 * Double.pi / 180.0

            // Inner ethereal halo ring (like POSY photo)
            var haloRing = Path()
            haloRing.addEllipse(in: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36))
            context.stroke(haloRing, with: .color(primaryColor.opacity(0.28)), lineWidth: 0.8)

            var outerHalo = Path()
            outerHalo.addEllipse(in: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52))
            context.stroke(outerHalo, with: .color(primaryColor.opacity(0.18)), lineWidth: 0.6)

            // Radiating fine filament whiskers with droplets
            for i in 0..<totalFilaments {
                let jitter = i < traits.perPetalJitter.count ? traits.perPetalJitter[i] : SampledFlowerTraits.PetalJitter(lengthScale: 1, widthScale: 1, angleOffset: 0, tintVariation: 0)
                let angle = Double(i) * goldenAngle + jitter.angleOffset

                // Staggered radii: inner layer, middle layer, outer layer
                let tierMod = i % 3
                let baseRadius: CGFloat = tierMod == 0 ? 38 : (tierMod == 1 ? 28 : 20)
                let length = baseRadius * CGFloat(jitter.lengthScale)

                let tipX = center.x + cos(angle) * length
                let tipY = center.y + sin(angle) * length

                // Radiating whisker filament
                var ray = Path()
                ray.move(to: center)
                ray.addLine(to: CGPoint(x: tipX, y: tipY))

                let whiskerColor = primaryColor.adjustedForWilt(desaturation: desaturation)
                context.stroke(ray, with: .color(whiskerColor.opacity(0.55)), lineWidth: 0.75)

                // Tiny droplet bead at tip (signature POSY dandelion look)
                let beadSize: CGFloat = tierMod == 0 ? 3.6 : 2.6
                var tuft = Path()
                tuft.addEllipse(in: CGRect(x: tipX - beadSize / 2, y: tipY - beadSize / 2, width: beadSize, height: beadSize))
                context.fill(tuft, with: .color(whiskerColor.opacity(0.92)))

                // Floating sparkle motes beyond tips
                if i % 4 == 0 {
                    let moteDist = length + 8.0 + CGFloat(i % 5) * 2.5
                    let moteX = center.x + cos(angle + 0.05) * moteDist
                    let moteY = center.y + sin(angle + 0.05) * moteDist
                    var mote = Path()
                    mote.addEllipse(in: CGRect(x: moteX - 1.2, y: moteY - 1.2, width: 2.4, height: 2.4))
                    context.fill(mote, with: .color(whiskerColor.opacity(0.7)))
                }
            }

            // Central core seedpod
            var core = Path()
            core.addEllipse(in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
            context.fill(core, with: .color(Color(red: 0.25, green: 0.32, blue: 0.30)))

            var coreInner = Path()
            coreInner.addEllipse(in: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5))
            context.fill(coreInner, with: .color(.white.opacity(0.85)))
        }
        .frame(width: 105, height: 105)
    }
}

// MARK: - 5. Simple Bowl Head (Poppy, Daisy)
private struct SimpleBowlHead: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let desaturation: Double
    let petalDropRatio: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let petalCount = max(4, Int(Double(traits.petalCount) * (1.0 - petalDropRatio)))
            let step = (Double.pi * 2) / Double(petalCount)

            for i in 0..<petalCount {
                let angle = Double(i) * step
                var petal = Path()
                petal.addEllipse(in: CGRect(x: -14, y: -34, width: 28, height: 36))

                let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(angle))
                context.fill(petal.applying(transform), with: .color(primaryColor.opacity(0.85).adjustedForWilt(desaturation: desaturation)))
            }

            // Center eye
            var eye = Path()
            eye.addEllipse(in: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18))
            context.fill(eye, with: .color(secondaryColor.adjustedForWilt(desaturation: desaturation)))
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - 6. Disc Ray Head (Sunflower 向日葵)
private struct DiscRaySunflower: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let desaturation: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = traits.petalCount
            let step = (Double.pi * 2) / Double(count)

            // Ray petals
            for i in 0..<count {
                let angle = Double(i) * step
                var ray = Path()
                ray.addEllipse(in: CGRect(x: -6, y: -38, width: 12, height: 38))
                let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(angle))
                context.fill(ray.applying(transform), with: .color(primaryColor.adjustedForWilt(desaturation: desaturation)))
            }

            // Large Fibonacci center disc
            var disc = Path()
            disc.addEllipse(in: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32))
            context.fill(disc, with: .color(Color(red: 0.36, green: 0.22, blue: 0.15)))

            // Inner golden speckles
            var innerDisc = Path()
            innerDisc.addEllipse(in: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))
            context.stroke(innerDisc, with: .color(Color(red: 0.88, green: 0.65, blue: 0.25).opacity(0.7)), lineWidth: 1.5)
        }
        .frame(width: 90, height: 90)
    }
}

// MARK: - 7. Bell Raceme (Lily of the Valley 铃兰)
private struct BellRacemeLily: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let desaturation: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let bells = traits.petalCount

            for i in 0..<bells {
                let yOffset = CGFloat(i) * 6.5 - 20
                let isLeft = i % 2 == 0
                let xOffset = isLeft ? -16.0 : 16.0

                // Drooping stalk
                var stalk = Path()
                stalk.move(to: CGPoint(x: center.x, y: center.y + yOffset))
                stalk.addQuadCurve(
                    to: CGPoint(x: center.x + CGFloat(xOffset), y: center.y + yOffset + 6),
                    control: CGPoint(x: center.x + CGFloat(xOffset * 0.6), y: center.y + yOffset - 2)
                )
                context.stroke(stalk, with: .color(Color(red: 0.38, green: 0.62, blue: 0.42)), lineWidth: 1.0)

                // Bell floret
                var bell = Path()
                bell.addEllipse(in: CGRect(x: center.x + CGFloat(xOffset) - 6, y: center.y + yOffset + 5, width: 12, height: 10))
                context.fill(bell, with: .color(primaryColor.adjustedForWilt(desaturation: desaturation)))
            }
        }
        .frame(width: 76, height: 84)
    }
}

// MARK: - 8. Cluster Wild (Clover 三叶草野花)
private struct ClusterWildClover: View {
    let recipe: SpeciesRecipe
    let traits: SampledFlowerTraits
    let primaryColor: Color
    let secondaryColor: Color
    let desaturation: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = traits.petalCount

            for i in 0..<count {
                let angle = Double(i) * 1.3
                let radius = Double(i * 3 + 4)
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius

                var floret = Path()
                floret.addEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                context.fill(floret, with: .color(primaryColor.adjustedForWilt(desaturation: desaturation)))
            }
        }
        .frame(width: 64, height: 64)
    }
}

// MARK: - Dissolve Burst View (Boundary 0 <-> -1 crossing)
private struct DissolveBurstView: View {
    let color: Color
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<18) { i in
                Circle()
                    .fill(color.opacity(Double(1.0 - progress)))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(Double(i) * 0.35) * Double(progress * 28),
                        y: sin(Double(i) * 0.35) * Double(progress * 28)
                    )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                progress = 1.0
            }
        }
    }
}
