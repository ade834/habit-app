import SwiftUI

struct BadgeGallery: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badges: [BadgeDefinition] = []
    @State private var unlocked: Set<Int> = []
    @State private var error: String?
    @State private var shimmer = false
    @State private var selectedBadge: BadgeDefinition?
    @State private var scrollDistance: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).fullViewportSurface()
            Color(red: 0.94, green: 0.94, blue: 0.97).opacity(0.72).fullViewportSurface()
            GeometryReader { geometry in
              let isWide = geometry.size.width >= 600
              let columns = isWide
                ? [GridItem(.adaptive(minimum: 145, maximum: 190), spacing: 20)]
                : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
              ZStack(alignment: .top) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: isWide ? 24 : 22) {
                        ForEach(badges.sorted { (unlocked.contains($0.id) ? 0 : 1, $0.id) < (unlocked.contains($1.id) ? 0 : 1, $1.id) }) { badge in
                            Button { selectedBadge = badge } label: {
                                BadgeCell(badge: badge, unlocked: unlocked.contains(badge.id), shimmer: shimmer)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, isWide ? 32 : 18)
                    .padding(.top, 100)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
                }
                .onScrollGeometryChange(for: CGFloat.self) { scroll in
                    max(0, scroll.contentOffset.y + scroll.contentInsets.top)
                } action: { _, distance in scrollDistance = distance }
                if isWide {
                    ScrollEdgeBlurOverlay(progress: min(1, scrollDistance / 70), visibility: .top, whiteOpacity: 0.18)
                        .ignoresSafeArea(.container, edges: [.top, .trailing])
                        .allowsHitTesting(false)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLanguage.text("成长徽章")).font(.system(size: 25, weight: .semibold, design: .serif))
                        Text(String(format: AppLanguage.text("已获得 %lld / 50"), unlocked.count)).font(.subheadline).foregroundStyle(Color(red: 0.39, green: 0.37, blue: 0.44))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44).background(.white.opacity(0.13), in: Circle())
                    }.accessibilityLabel(AppLanguage.text("关闭徽章"))
                }
                .foregroundStyle(Color(red: 0.25, green: 0.23, blue: 0.30)).padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 18)
                if let error { Text(error).font(.footnote).foregroundStyle(.primary).padding(.top, 100) }
              }
            }
            if let badge = selectedBadge {
                Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { selectedBadge = nil }
                BadgeDetailCard(badge: badge, unlocked: unlocked.contains(badge.id)) { selectedBadge = nil }
                    .id(badge.id)
                    .padding(20)
            }
        }
        .presentationBackground(.clear)
        .task {
            do {
                badges = try BadgeCatalog.load()
                unlocked = try BadgeProgressStore().refresh()
            } catch { self.error = AppLanguage.text("徽章读取失败，请稍后再试。") }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { shimmer = true }
        }
    }
}

private struct BadgeDetailCard: View {
    let badge: BadgeDefinition
    let unlocked: Bool
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var floating = false
    private let ink = Color(red: 0.24, green: 0.22, blue: 0.29)

    private func reveal(_ delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.55).delay(delay)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44).background(.white.opacity(0.55), in: Circle())
            }.accessibilityLabel(AppLanguage.text("关闭徽章详情")) }
            if let url = Bundle.main.url(forResource: badge.imageResourceName, withExtension: "png"), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().frame(width: 190, height: 190)
                    .opacity(visible ? 1 : 0).scaleEffect(visible ? 1 : 0.91)
                    .offset(y: visible ? (floating ? -3 : 0) : 10)
                    .animation(reveal(0.05), value: visible)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: floating)
            }
            Text(AppLanguage.text(badge.name)).font(.system(size: 24, weight: .semibold, design: .serif))
                .padding(.top, 22).opacity(visible ? 1 : 0).offset(y: visible ? 0 : 8).animation(reveal(0.20), value: visible)
            Text(AppLanguage.text(unlocked ? "已获得" : ([28, 29, 49, 50].contains(badge.id) ? "记录待完善" : "尚未获得")))
                .font(.subheadline).foregroundStyle(ink.opacity(0.68)).padding(.top, 8)
                .opacity(visible ? 1 : 0).offset(y: visible ? 0 : 8).animation(reveal(0.30), value: visible)
            Text(AppLanguage.text("获得条件")).font(.caption.weight(.semibold)).foregroundStyle(ink.opacity(0.62)).padding(.top, 28)
                .opacity(visible ? 1 : 0).offset(y: visible ? 0 : 8).animation(reveal(0.40), value: visible)
            Text(AppLanguage.text(badge.requirement)).font(.body).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10).opacity(visible ? 1 : 0).offset(y: visible ? 0 : 8).animation(reveal(0.50), value: visible)
        }
        .foregroundStyle(ink).padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 54).frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .background(.white.opacity(0.67), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.7), lineWidth: 1))
        .task { visible = true; if !reduceMotion { floating = true } }
    }
}

private struct BadgeCell: View {
    let badge: BadgeDefinition
    let unlocked: Bool
    let shimmer: Bool
    private var needsMoreHistory: Bool { [28, 29, 49, 50].contains(badge.id) && !unlocked }
    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                ZStack {
                    if unlocked {
                        ZStack {
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.25), .white.opacity(0.09), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.49))
                            Circle().stroke(
                                AngularGradient(colors: [.clear, .white.opacity(0.10), .white.opacity(0.95), .white.opacity(0.20), .clear, .clear], center: .center),
                                lineWidth: 6
                            )
                            .blur(radius: 3)
                            .padding(proxy.size.width * 0.12)
                            .rotationEffect(.degrees(shimmer ? 160 : -40))
                            .opacity(shimmer ? 0.95 : 0.6)
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.8), .white.opacity(0.12), .clear], center: shimmer ? .topTrailing : .bottomLeading, startRadius: 0, endRadius: proxy.size.width * 0.42))
                                .padding(proxy.size.width * 0.04)
                        }.padding(2)
                    }
                    if let url = Bundle.main.url(forResource: badge.imageResourceName, withExtension: "png"), let image = UIImage(contentsOfFile: url.path) {
                        ZStack {
                            Image(uiImage: image).resizable().scaledToFit().saturation(0).brightness(-0.25).offset(x: 2.5, y: 1.5)
                            Image(uiImage: image).resizable().scaledToFit()
                        }.padding(17).rotation3DEffect(.degrees(unlocked ? -9 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                            .shadow(color: .black.opacity(unlocked ? 0.26 : 0), radius: 3, x: 0, y: 3)
                            .overlay { Circle().stroke(.white.opacity(unlocked ? 0.16 : 0), lineWidth: 0.8).padding(19) }
                            .saturation(unlocked ? 1 : 0).opacity(unlocked ? 1 : 0.28)
                    }
                    if !unlocked { Image(systemName: "lock.fill").font(.system(size: 16)).foregroundStyle(Color(red: 0.32, green: 0.30, blue: 0.38).opacity(0.8)) }
                }
                .frame(width: proxy.size.width, height: proxy.size.height).clipped()
            }.aspectRatio(1, contentMode: .fit)
            Text(AppLanguage.text(badge.name)).font(.system(size: 12, weight: .medium)).foregroundStyle(Color(red: 0.25, green: 0.23, blue: 0.30).opacity(unlocked ? 1 : 0.7)).lineLimit(2).multilineTextAlignment(.center)
            if needsMoreHistory {
                Text(AppLanguage.text("记录待完善")).font(.system(size: 10)).foregroundStyle(Color(red: 0.35, green: 0.33, blue: 0.40).opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppLanguage.text(badge.name)), \(AppLanguage.text(unlocked ? "已获得" : needsMoreHistory ? "记录待完善" : "尚未获得")), \(AppLanguage.text(badge.requirement))")
    }
}
