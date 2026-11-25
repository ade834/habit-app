import SwiftUI
import MetalKit
import UIKit

struct LabSettings {
    var refraction = 24.0
    var blur = 1.5
    var thickness = 24.0
    var curvature = 28.0
    var highlight = 0.55
    var dispersion = 3.0
    var pressure = 0.12
    var bounce = 0.45
    var separation = 100.0
    var fusion = 24.0
}

struct SceneBackground: View {
    var style: Int
    var dark: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack {
                (dark ? Color(red: 0.04, green: 0.07, blue: 0.16) : Color(red: 0.91, green: 0.94, blue: 0.98))
                if style == 0 {
                    LinearGradient(colors: [.indigo, .cyan, .mint, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.blue).frame(width: 220).blur(radius: 25).offset(x: -100, y: -70)
                    Circle().fill(.pink).frame(width: 180).blur(radius: 15).offset(x: 100, y: 65)
                    Text("GLASS").font(.system(size: 72, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.6)).rotationEffect(.degrees(-18))
                    stripes(size: geo.size, spacing: 24, opacity: 0.25)
                } else if style == 1 {
                    stripes(size: geo.size, spacing: 16, opacity: dark ? 0.35 : 0.25)
                    HStack(spacing: 36) {
                        ForEach(0..<5) { _ in Rectangle().fill(.cyan).frame(width: 5) }
                    }.rotationEffect(.degrees(20))
                    Text("0123456789").font(.system(size: 34, weight: .black, design: .monospaced)).foregroundStyle(dark ? .white : .black)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OPTICAL STUDY").font(.caption.monospaced()).tracking(5)
                        Text("光穿过玻璃\n世界发生弯曲").font(.system(size: 30, weight: .bold))
                        HStack {
                            ForEach(0..<4) { i in
                                RoundedRectangle(cornerRadius: 12).fill([Color.orange, .cyan, .pink, .purple][i]).frame(height: 45)
                            }
                        }
                        Text("Refraction / Dispersion / Surface tension").font(.caption.monospaced())
                    }.padding(24).foregroundStyle(dark ? .white : .black)
                }
            }.frame(width: geo.size.width, height: geo.size.height).clipped()
        }
    }
    private func stripes(size: CGSize, spacing: CGFloat, opacity: Double) -> some View {
        Canvas { context, _ in
            var path = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
                path.move(to: CGPoint(x:x,y:0)); path.addLine(to:CGPoint(x:x,y:size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
                path.move(to: CGPoint(x:0,y:y)); path.addLine(to:CGPoint(x:size.width,y:y))
            }
            context.stroke(path, with: .color((dark ? Color.white : .black).opacity(opacity)), lineWidth: 1)
        }
    }
}


// Compile the source at runtime. This avoids requiring Xcode's optional offline Metal toolchain.
struct OpticalSurface: View, Animatable {
    var size: CGSize
    var center: CGPoint
    var shape: Int
    var scale: Double
    var settings: LabSettings
    var multiple: Bool
    var background: Int
    var dark: Bool
    var liveBackdrop = false
    var animatableData: Double {
        get { scale }
        set { scale = newValue }
    }
    var body: some View {
        MetalSurface(size: size, center: center, shape: shape, scale: scale, settings: settings,
                     multiple: multiple, background: background, dark: dark, liveBackdrop: liveBackdrop)
    }
}

struct MetalSurface: UIViewRepresentable {
    var size: CGSize
    var center: CGPoint
    var shape: Int
    var scale: Double
    var settings: LabSettings
    var multiple: Bool
    var background: Int
    var dark: Bool
    var liveBackdrop = false
    func makeCoordinator() -> Renderer { Renderer() }
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.isPaused = !liveBackdrop
        view.enableSetNeedsDisplay = !liveBackdrop
        view.preferredFramesPerSecond = 30
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.delegate = context.coordinator
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        let r = context.coordinator
        r.update(from: self)
        if !liveBackdrop { view.setNeedsDisplay() }
    }
    static func dismantleUIView(_ view: MTKView, coordinator: Renderer) {
        view.isPaused = true
        view.delegate = nil
    }
}

@MainActor final class Renderer: NSObject, MTKViewDelegate {
    let device = MTLCreateSystemDefaultDevice()
    var queue: MTLCommandQueue?
    var pipeline: MTLRenderPipelineState?
    var texture: MTLTexture?
    var cacheKey = ""
    var liveBackdrop = false
    var uniforms = [Float](repeating: 0, count: 16)
    override init() {
        super.init()
        do {
            guard let device else { throw LabError.unavailable }
            queue = device.makeCommandQueue()
            let url = Bundle.main.url(forResource: "LiquidOptics", withExtension: "metal.txt")!
            let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "fullScreen")
            descriptor.fragmentFunction = library.makeFunction(name: "liquidOptics")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            print("Liquid Glass Lab: runtime Metal pipeline ready")
        } catch {
            print("Liquid Glass Lab: Metal initialization failed: \(error)")
        }
    }
    func update(from value: MetalSurface) {
        liveBackdrop = value.liveBackdrop
        let s = value.settings
        // Keep the user's saved optical distances in points. Only the lens
        // geometry adapts to the navigation capsule's available size.
        let unit: Float = 1
        uniforms = [Float(value.size.width), Float(value.size.height), Float(value.center.x), Float(value.center.y),
                    Float(value.shape), Float(value.scale), Float(s.refraction) * unit,
                    Float(s.blur) * unit, Float(s.thickness) * unit,
                    Float(s.curvature), Float(s.highlight), Float(s.dispersion) * unit,
                    value.multiple ? 1 : 0, Float(s.separation) * unit, Float(s.fusion) * unit, value.liveBackdrop ? Float(value.size.width / max(value.size.height, 1)) : 1.58]
        guard !liveBackdrop else { return }
        let key = "\(value.background)-\(value.dark)-\(value.size)"
        guard key != cacheKey else { return }
        let renderer = ImageRenderer(content: SceneBackground(style: value.background, dark: value.dark)
            .frame(width: value.size.width, height: value.size.height)
            .environment(\.colorScheme, value.dark ? .dark : .light))
        renderer.scale = 2
        if let cg = renderer.cgImage {
            upload(cg)
            cacheKey = key
        }
    }

    private func captureBackdrop(behind view: MTKView) {
        guard let window = view.window, view.bounds.width > 0, view.bounds.height > 0 else { return }
        var exclusion: UIView? = view
        while let current = exclusion,
              current.accessibilityIdentifier != opticalNavigationExclusionID {
            exclusion = current.superview
        }
        guard let exclusion else { return }
        let region = view.convert(view.bounds, to: window)
        guard region.width > 0, region.height > 0 else { return }
        let wasHidden = exclusion.isHidden
        exclusion.isHidden = true
        defer { exclusion.isHidden = wasHidden }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: format)
        let image = renderer.image { context in
            context.cgContext.scaleBy(x: view.bounds.width / region.width,
                                      y: view.bounds.height / region.height)
            context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            // Read the model layer tree after excluding the navigation host.
            // drawHierarchy(afterScreenUpdates: false) can reuse a compositor
            // snapshot that still contains our previous lens and its text.
            window.layer.render(in: context.cgContext)
        }
        if let cg = image.cgImage { upload(cg) }
    }

    private func upload(_ image: CGImage) {
        guard let device else { return }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let madeImage = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard madeImage else { return }
        if texture?.width != width || texture?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            texture = device.makeTexture(descriptor: descriptor)
        }
        pixels.withUnsafeBytes { bytes in
            texture?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                             withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
        }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    func draw(in view: MTKView) {
        if liveBackdrop { captureBackdrop(behind: view) }
        guard let pipeline, let texture, let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor, let command = queue?.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(uniforms, length: uniforms.count * MemoryLayout<Float>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }
    enum LabError: Error { case unavailable }
}

/// Original Lab optics with the current page supplied as the live input texture.
struct SavedOpticalNavigationSurface: View {
    private let settings = LabSettings(
        refraction: 38.142,
        blur: 2.8,
        thickness: 8.253,
        curvature: 29.325,
        highlight: 0.54,
        dispersion: 3,
        pressure: 0.117,
        bounce: 0.143,
        separation: 100,
        fusion: 24
    )

    var body: some View {
        GeometryReader { geometry in
            OpticalSurface(
                size: geometry.size,
                center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2),
                shape: 0,
                scale: geometry.size.height / 100,
                settings: settings,
                multiple: false,
                background: 2,
                dark: true,
                liveBackdrop: true
            )
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private let opticalNavigationExclusionID = "HabitOpticalNavigationHost"

/// Isolate the navigation in its own UIKit host so the optical renderer can
/// sample the page beneath it without re-sampling its own lens or button text.
struct LiveOpticalNavigationHost<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.accessibilityIdentifier = opticalNavigationExclusionID
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<Content>, context: Context) {
        controller.rootView = content
    }
}
