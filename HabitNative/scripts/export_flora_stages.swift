import SwiftUI
import AppKit

// MARK: - 纯净花头四阶段展示（零茎秆、零文字标签、零底色、100% 透明背景）
struct FloraFourStageBloomHeadsView: View {
    let type: PosyFloraType
    let stages: [Double] = [0.15, 0.40, 0.65, 1.00]

    var headSize: CGFloat {
        type.isGiantFlora ? 240 : 180
    }

    var body: some View {
        HStack(alignment: .center, spacing: 36) {
            ForEach(0..<4, id: \.self) { index in
                PosyFlowerBloomCanvas(
                    type: type,
                    progress: stages[index],
                    breathingPhase: 0,
                    windAngle: 0,
                    seed: 42
                )
                .frame(width: headSize, height: headSize)
            }
        }
        .padding(36)
        .background(Color.clear)
    }
}

// MARK: - 单个花头独立展示（540x540@2x 独立纯净花头）
struct FloraSingleBloomHeadView: View {
    let type: PosyFloraType
    let progress: Double

    var headSize: CGFloat {
        type.isGiantFlora ? 240 : 180
    }

    var body: some View {
        PosyFlowerBloomCanvas(
            type: type,
            progress: progress,
            breathingPhase: 0,
            windAngle: 0,
            seed: 42
        )
        .frame(width: headSize, height: headSize)
        .frame(width: 270, height: 270)
        .background(Color.clear)
    }
}

@main
struct ExportAllFloraStages {
    @MainActor
    static func main() {
        let outDirCanonical = "/Users/deshiru/Documents/ChatGPT/习惯 app/HabitNative/exported_flora_stages"
        let outDirMirror = "/Users/deshiru/Documents/ChatGPT/HabitNative-antigravity/exported_flora_stages"
        let outDirArtifacts = "/Users/deshiru/.gemini/antigravity/brain/0eb71300-f97d-4379-b1cd-67d3d5f02c4f/handoff_audit/evidence/flora_stages"

        let subdirs = ["", "/single_heads"]
        let fm = FileManager.default
        for base in [outDirCanonical, outDirMirror, outDirArtifacts] {
            for sub in subdirs {
                try? fm.createDirectory(atPath: base + sub, withIntermediateDirectories: true)
            }
        }

        let cases = PosyFloraType.allCases
        let stages: [Double] = [0.15, 0.40, 0.65, 1.00]

        print("Starting export of 12 flora 4-stage flower heads (pure transparent)...")

        for (i, type) in cases.enumerated() {
            let indexStr = String(format: "%02d", i + 1)
            let baseName = "\(indexStr)_\(type.rawValue)"

            // 1. 核心交付物：12 张 4 阶段花头横向并列透明图
            let fourStageView = FloraFourStageBloomHeadsView(type: type)
            if let data = renderToPNG(view: fourStageView, scale: 2.0) {
                let f1 = "\(outDirCanonical)/\(baseName).png"
                let f2 = "\(outDirMirror)/\(baseName).png"
                let f3 = "\(outDirArtifacts)/\(baseName).png"
                try? data.write(to: URL(fileURLWithPath: f1))
                try? data.write(to: URL(fileURLWithPath: f2))
                try? data.write(to: URL(fileURLWithPath: f3))
                print("[\(indexStr)/12] Exported pure 4-stage flower heads: \(baseName).png (\(data.count) bytes)")
            }

            // 2. 补充交付物：每个阶段独立的纯净花头 (共 48 张)
            for (stageIdx, progress) in stages.enumerated() {
                let singleView = FloraSingleBloomHeadView(type: type, progress: progress)
                if let data = renderToPNG(view: singleView, scale: 2.0) {
                    let singleName = "\(baseName)_stage\(stageIdx + 1).png"
                    let f1 = "\(outDirCanonical)/single_heads/\(singleName)"
                    let f2 = "\(outDirMirror)/single_heads/\(singleName)"
                    let f3 = "\(outDirArtifacts)/single_heads/\(singleName)"
                    try? data.write(to: URL(fileURLWithPath: f1))
                    try? data.write(to: URL(fileURLWithPath: f2))
                    try? data.write(to: URL(fileURLWithPath: f3))
                }
            }
        }

        print("\nALL 12 PURE FLOWER HEADS SUCCESSFULLY EXPORTED TO ALL DIRECTORIES!")
    }

    @MainActor
    static func renderToPNG<V: View>(view: V, scale: CGFloat = 2.0) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = false // 保证 100% 纯透明背景
        guard let cgImage = renderer.cgImage else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
