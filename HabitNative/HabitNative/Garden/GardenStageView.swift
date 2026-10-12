import SwiftUI

// MARK: - Garden Interactive Stage View
struct GardenStageView: View {
    @ObservedObject var viewModel: GardenHabitViewModel
    let stageSize: CGSize

    @State private var dragOffsets: [String: CGSize] = [:]
    @State private var draggingId: String? = nil
    @State private var tickerPhase: Double = 0
    @State private var beePosition: CGPoint = CGPoint(x: 160, y: 140)
    @State private var beeWingPhase: Double = 0

    init(viewModel: GardenHabitViewModel, stageSize: CGSize) {
        self.viewModel = viewModel
        self.stageSize = stageSize
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let breathing = sin(elapsed * 2.2)
            let sway = sin(elapsed * 1.4 + Double(viewModel.windOffset)) * 0.08

            ZStack(alignment: .bottom) {
                // 0. Background Tap Area for Wind (Non-interfering behind flowers)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interpolatingSpring(stiffness: 100, damping: 9)) {
                            viewModel.windOffset = 5.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring()) {
                                viewModel.windOffset = 0
                            }
                        }
                    }

                // 1. Glowing Translucent Glass Vessel (Saucer / Plate Rim)
                GlowingVesselSaucerView()
                    .frame(width: stageSize.width * 0.90, height: 95)
                    .offset(y: -stageSize.height * 0.16)

                // 2. Companion Foliage (Tier B species accompaniment)
                CompanionFoliageView(swayOffset: CGFloat(sway * 18))
                    .frame(width: stageSize.width * 0.82, height: 90)
                    .offset(y: -stageSize.height * 0.19)

                // 3. Interactive Procedural Flowers (Sorted by Stem Base Y, Spec Section 6)
                let sortedItems = viewModel.items.sorted { item1, item2 in
                    if item1.id == viewModel.lastTouchedId { return false }
                    if item2.id == viewModel.lastTouchedId { return true }
                    return item1.record.position.y < item2.record.position.y
                }

                ForEach(sortedItems) { item in
                    InteractiveFlowerItemView(
                        item: item,
                        stageSize: stageSize,
                        currentDrag: dragOffsets[item.id] ?? .zero,
                        isDragging: draggingId == item.id,
                        isFocused: viewModel.focusedHabitId == item.id,
                        windSway: sway + Double(viewModel.windOffset * 0.03),
                        breathingPhase: breathing,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.selectedItem = item
                                viewModel.focusedHabitId = item.id
                            }
                        },
                        onDoubleTap: {
                            viewModel.triggerBurst(for: item.id)
                        },
                        onDragChanged: { translation in
                            draggingId = item.id
                            dragOffsets[item.id] = translation
                            viewModel.lastTouchedId = item.id
                            viewModel.focusedHabitId = item.id
                        },
                        onDragEnded: { translation in
                            draggingId = nil
                            let normX = item.record.position.x
                            let normY = item.record.position.y
                            let newX = min(max((normX * stageSize.width + translation.width) / stageSize.width, 0.12), 0.88)
                            let newNormYFromTop = (stageSize.height * (1.0 - normY) + translation.height) / stageSize.height
                            let actualNormY = min(max(1.0 - newNormYFromTop, 0.08), 0.45)

                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                dragOffsets[item.id] = .zero
                            }
                            viewModel.updatePosition(for: item.id, newPosition: CGPoint(x: newX, y: actualNormY))
                        }
                    )
                }

                // 4. Little Ladybug sitting on the vessel rim (Matching POSY photo)
                LadybugSpriteView()
                    .position(x: stageSize.width * 0.54, y: stageSize.height * 0.73)

                // 5. Living Bee hovering near flowers
                let beeX = stageSize.width * 0.50 + CGFloat(sin(elapsed * 1.8) * 45)
                let beeY = stageSize.height * 0.32 + CGFloat(cos(elapsed * 2.4) * 22)

                BeeSpriteView(wingPhase: elapsed * 42)
                    .position(x: beeX, y: beeY)

                // 6. Floating Bokeh Orbs & Sparkle Particles (Matching POSY dreamscape)
                FloatingBokehParticles(elapsed: elapsed)
            }
            .frame(width: stageSize.width, height: stageSize.height)
            .coordinateSpace(name: "GardenStageCanvas")
        }
    }
}

// MARK: - Interactive Single Flower Item View (Interactive Dragging & Tilt)
private struct InteractiveFlowerItemView: View {
    let item: HabitGardenItem
    let stageSize: CGSize
    let currentDrag: CGSize
    let isDragging: Bool
    let isFocused: Bool
    let windSway: Double
    let breathingPhase: Double
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    var body: some View {
        let recipe = GardenRecipeRegistry.shared.recipe(for: item.record.species)
        let traits = SampledFlowerTraits.sample(from: recipe, recordId: item.id)

        let normX = item.record.position.x
        let normY = item.record.position.y
        let posX = normX * stageSize.width + currentDrag.width
        let posY = stageSize.height * (1.0 - normY) + currentDrag.height

        // Dynamic interactive stem tilt according to finger drag vector (随着手指方向产生互动)
        let dragTilt = isDragging ? min(max(Double(currentDrag.width) * 0.24, -30.0), 30.0) : 0.0

        ZStack(alignment: .bottom) {
            // Focus or drag glowing aura
            if isFocused || isDragging {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isDragging ? Color(red: 1.0, green: 0.90, blue: 0.65).opacity(0.60) : Color.white.opacity(0.38),
                                Color(red: 1.0, green: 0.85, blue: 0.70).opacity(0.20),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: isDragging ? 64 : 52
                        )
                    )
                    .frame(width: isDragging ? 128 : 104, height: isDragging ? 128 : 104)
                    .offset(y: 10)
                    .transition(.scale.combined(with: .opacity))
            }

            FlowerProceduralView(
                record: item.record,
                recipe: recipe,
                traits: traits,
                renderLevel: item.renderLevel,
                windAngle: windSway,
                breathingPhase: breathingPhase + traits.wobblePhase,
                isDissolving: item.isDissolving,
                dragLeanAngle: dragTilt
            )
            .scaleEffect(isDragging ? 1.08 : 1.0, anchor: .bottom)
            .shadow(color: isDragging ? Color.black.opacity(0.20) : Color.clear, radius: 10, x: 0, y: 8)
        }
        .frame(width: 82, height: 260, alignment: .bottom)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .named("GardenStageCanvas"))
                .onChanged { gesture in
                    onDragChanged(gesture.translation)
                }
                .onEnded { gesture in
                    onDragEnded(gesture.translation)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onDoubleTap()
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                onTap()
            }
        )
        .position(x: posX, y: posY - 130)
    }
}

// MARK: - Glowing Translucent Vessel (Saucer Plate)
private struct GlowingVesselSaucerView: View {
    var body: some View {
        ZStack {
            // Soft radiant glow under vessel
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.65), Color(red: 0.98, green: 0.88, blue: 0.92).opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(height: 70)
                .blur(radius: 12)

            // Frosted glass rim
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.25), Color(red: 0.95, green: 0.80, blue: 0.85).opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.2
                )
                .background(
                    Ellipse()
                        .fill(Color.white.opacity(0.32))
                        .blur(radius: 2)
                )
                .shadow(color: Color(red: 0.92, green: 0.55, blue: 0.65).opacity(0.25), radius: 14, x: 0, y: 6)
        }
    }
}

// MARK: - Floating Bokeh Particles
private struct FloatingBokehParticles: View {
    let elapsed: Double

    var body: some View {
        Canvas { context, size in
            let particles: [(cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color, speed: Double)] = [
                (size.width * 0.12, size.height * 0.28, 14, Color(red: 0.28, green: 0.45, blue: 0.72).opacity(0.35), 0.6),
                (size.width * 0.88, size.height * 0.32, 22, Color(red: 0.98, green: 0.78, blue: 0.65).opacity(0.4), 0.4),
                (size.width * 0.32, size.height * 0.30, 9, Color(red: 0.20, green: 0.58, blue: 0.62).opacity(0.45), 0.8),
                (size.width * 0.75, size.height * 0.25, 12, Color(red: 0.94, green: 0.38, blue: 0.55).opacity(0.35), 0.5),
                (size.width * 0.86, size.height * 0.54, 16, Color(red: 0.25, green: 0.35, blue: 0.65).opacity(0.3), 0.7),
                (size.width * 0.15, size.height * 0.65, 8, Color(red: 0.88, green: 0.32, blue: 0.58).opacity(0.4), 0.9)
            ]

            for p in particles {
                let dy = CGFloat(sin(elapsed * p.speed)) * 6.0
                let dx = CGFloat(cos(elapsed * (p.speed * 0.8))) * 4.0
                var circle = Path()
                circle.addEllipse(in: CGRect(x: p.cx + dx - p.r, y: p.cy + dy - p.r, width: p.r * 2, height: p.r * 2))
                context.fill(circle, with: .color(p.color))
            }
        }
    }
}
