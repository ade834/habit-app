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
            let cardWidth = min(proxy.size.width - 40, 380.0)

            ZStack {
                GardenBackdropBlur()
                    .ignoresSafeArea()
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("这一刻，值得珍藏")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.27, green: 0.22, blue: 0.27))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.white.opacity(0.9)))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭拍立得")
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

                            GardenPolaroidActions(
                                isSaving: isSaving,
                                onSave: saveToPhotos,
                                onShare: {
                                    if let image = renderedPrint() {
                                        shareItem = GardenShareItem(image: image)
                                    } else {
                                        notice = "照片暂时无法生成，请重试。"
                                    }
                                }
                            )
                            .frame(width: cardWidth)
                            .padding(.bottom, 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.horizontal, 20)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.62, dampingFraction: 0.82)) {
                hasAppeared = true
            }
        }
        .sheet(item: $shareItem) { item in
            GardenActivitySheet(image: item.image)
        }
        .alert("拍立得", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("知道了", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
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
            notice = "照片暂时无法生成，请重试。"
            return
        }
        isSaving = true
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                isSaving = false
                notice = "请在系统设置中允许添加照片。"
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                notice = "已保存到照片图库。"
            } catch {
                notice = "保存失败：\(error.localizedDescription)"
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
                .accessibilityLabel("养成花园照片")
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
                        TextField("写下这一刻的心情", text: $caption, axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityLabel("写下这一刻的心情")
                            .onChange(of: caption) { _, value in
                                if value.count > 40 { caption = String(value.prefix(40)) }
                            }
                    } else {
                        Text(caption.isEmpty ? "持续绽放" : caption)
                    }
                }
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.27, green: 0.22, blue: 0.27))
                .multilineTextAlignment(.center)
                .frame(width: imageWidth * 2.0 / 3.0)

                Spacer(minLength: 10)

                Text("POSY GARDEN · HABIT APP")
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
                    Label(isSaving ? "保存中" : "保存到相册", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isSaving)

                Button(action: onShare) {
                    Label("分享", systemImage: "square.and.arrow.up")
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
