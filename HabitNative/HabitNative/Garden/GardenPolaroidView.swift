import Photos
import SwiftUI
import UIKit

struct GardenPolaroidView: View {
    let photo: UIImage
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var caption = ""
    @State private var hasAppeared = false
    @State private var isSaving = false
    @State private var notice: String?
    @State private var shareItem: GardenShareItem?

    var body: some View {
        GeometryReader { proxy in
            let trailingInset = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?.safeAreaInsets.right ?? 0
            let usesSideActions = trailingInset >= 30 && proxy.size.width > proxy.size.height
            let contentWidth = proxy.size.width - (usesSideActions ? trailingInset : 0)
            let cardWidth = min(contentWidth - 40, 380.0)

            ZStack {
                GardenBackdropBlur()
                    .fullViewportSurface()
                Color.black.opacity(0.25)
                    .fullViewportSurface()

                VStack(spacing: 0) {
                    HStack {
                        Text(AppLanguage.text("这一刻，值得珍藏"))
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Spacer()
                        if !usesSideActions { Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.27, green: 0.22, blue: 0.27))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.white.opacity(0.9)))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppLanguage.text("关闭拍立得"))
                        }
                    }
                    .frame(maxWidth: cardWidth)
                    .padding(.top, 12)

                    ScrollView {
                        VStack(spacing: 16) {
                            Spacer(minLength: 12)

                            GardenPolaroidPrint(photo: photo, caption: $caption, width: cardWidth, isEditable: true)
                                .rotationEffect(.degrees(hasAppeared || reduceMotion ? -1.0 : 0))
                                .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.68)
                                .opacity(hasAppeared ? 1 : 0)

                            // Center the controls in the quiet space beneath the print.
                            Spacer(minLength: 68)

                            if !usesSideActions { GardenPolaroidActions(
                                isSaving: isSaving,
                                onSave: saveToPhotos,
                                onShare: {
                                    if let image = renderedPrint() {
                                        shareItem = GardenShareItem(image: image)
                                    } else {
                                        notice = AppLanguage.text("照片暂时无法生成，请重试。")
                                    }
                                }
                            )
                            .frame(width: cardWidth)
                            .padding(.bottom, 16)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.horizontal, 20)
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity, alignment: .leading)

                if usesSideActions {
                    VStack(spacing: 18) {
                        sideAction(AppLanguage.text("关闭拍立得"), systemImage: "xmark", action: onDismiss)
                        sideAction(AppLanguage.text("保存到相册"), systemImage: "square.and.arrow.down", action: saveToPhotos)
                            .disabled(isSaving)
                        sideAction(AppLanguage.text("分享"), systemImage: "square.and.arrow.up") {
                            if let image = renderedPrint() {
                                shareItem = GardenShareItem(image: image)
                            } else {
                                notice = AppLanguage.text("照片暂时无法生成，请重试。")
                            }
                        }
                    }
                    .position(x: contentWidth + trailingInset / 2, y: proxy.size.height / 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: .trailing)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.62, dampingFraction: 0.82)) {
                hasAppeared = true
            }
        }
        .sheet(item: $shareItem) { item in
            GardenActivitySheet(image: item.image)
        }
        .alert(AppLanguage.text("拍立得"), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(AppLanguage.text("知道了"), role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    private func sideAction(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color(red: 0.27, green: 0.22, blue: 0.27))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.78)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    @MainActor
    private func renderedPrint() -> UIImage? {
        let renderer = ImageRenderer(content: GardenPolaroidPrint(photo: photo, caption: .constant(caption), width: 380, isEditable: false))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func saveToPhotos() {
        guard let image = renderedPrint() else {
            notice = AppLanguage.text("照片暂时无法生成，请重试。")
            return
        }
        isSaving = true
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                isSaving = false
                shareItem = GardenShareItem(image: image)
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                notice = AppLanguage.text("已保存到照片图库。")
            } catch {
                notice = String(format: AppLanguage.text("保存失败：%@"), error.localizedDescription)
            }
            isSaving = false
        }
    }
}

private struct GardenPolaroidPrint: View {
    let photo: UIImage
    @Binding var caption: String
    let width: CGFloat
    let isEditable: Bool

    var body: some View {
        let inset: CGFloat = 13
        let imageWidth = width - inset * 2

        VStack(spacing: 0) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: imageWidth, height: imageWidth * 1.04)
                .compositingGroup()
                .accessibilityLabel(AppLanguage.text("养成花园照片"))
                .overlay {
                    // A nearly imperceptible edge keeps the snapshot contained
                    // without introducing a bottom seam above the caption area.
                    ZStack(alignment: .top) {
                        LinearGradient(
                            colors: [.black.opacity(0.018), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 4)

                        HStack(spacing: 0) {
                            LinearGradient(
                                colors: [.black.opacity(0.014), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 3)
                            Spacer(minLength: 0)
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.014)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 3)
                        }
                    }
                    .blur(radius: 0.8)
                    .allowsHitTesting(false)
                }
                .clipShape(Rectangle())

            VStack(spacing: 0) {
                Spacer(minLength: 18)
                Group {
                    if isEditable {
                        TextField(AppLanguage.text("写下这一刻的心情"), text: $caption, axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityLabel(AppLanguage.text("写下这一刻的心情"))
                            .onChange(of: caption) { _, value in
                                if value.count > 40 { caption = String(value.prefix(40)) }
                            }
                    } else {
                        Text(caption.isEmpty ? AppLanguage.text("持续绽放") : caption)
                    }
                }
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.27, green: 0.22, blue: 0.27))
                .multilineTextAlignment(.center)
                .frame(width: imageWidth * 2.0 / 3.0)

                Spacer(minLength: 10)

                Text("MAYBII GARDEN · HABIT APP")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(0.675)
                .foregroundStyle(Color(red: 0.58, green: 0.51, blue: 0.54))
                .padding(.bottom, 9)
            }
            .frame(width: imageWidth, height: 140)
        }
        .padding(inset)
        .frame(width: width)
        .background(Color(red: 1.0, green: 0.992, blue: 0.978))
    }
}

private struct GardenPolaroidActions: View {
    let isSaving: Bool
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onSave) {
                    Label(isSaving ? AppLanguage.text("保存中") : AppLanguage.text("保存到相册"), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isSaving)

                Button(action: onShare) {
                    Label(AppLanguage.text("分享"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(GardenPolaroidActionStyle())
        }
    }
}

private struct GardenPolaroidActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.32, green: 0.24, blue: 0.31))
            .frame(height: 49)
            .padding(.horizontal, 8)
            .glassEffect(
                .regular.tint(Color.white.opacity(configuration.isPressed ? 0.40 : 0.58)).interactive(),
                in: .capsule
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct GardenBackdropBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

private struct GardenShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct GardenActivitySheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
