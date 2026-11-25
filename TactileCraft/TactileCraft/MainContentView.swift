import SwiftUI

enum CraftTab: Int, CaseIterable, Identifiable {
    case typewriter = 0
    case rolodex = 1
    case receipt = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .typewriter: return "打字机"
        case .rolodex: return "信封滚轮"
        case .receipt: return "灵动岛小票"
        }
    }

    var icon: String {
        switch self {
        case .typewriter: return "character.cursor.ibeam"
        case .rolodex: return "tray.2.fill"
        case .receipt: return "printer.fill"
        }
    }
}

struct MainContentView: View {
    @State private var selectedTab: CraftTab = .typewriter

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主展示内容区（使用 Switch 条件渲染，避免 TabView 页面滑动手势与滚轮手势冲突）
            ZStack {
                switch selectedTab {
                case .typewriter:
                    TypewriterSceneView()
                        .transition(.opacity)
                case .rolodex:
                    RolodexEnvelopeView()
                        .transition(.opacity)
                case .receipt:
                    DynamicIslandReceiptView()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // 悬浮拟物底栏导航 (Floating Dock)
            HStack(spacing: 8) {
                ForEach(CraftTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                            TactileFeedbackManager.shared.playRolodexTick()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .bold))

                            if selectedTab == tab {
                                Text(tab.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.7))
                        .padding(.horizontal, selectedTab == tab ? 16 : 12)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? Capsule().fill(Color.white)
                                : Capsule().fill(Color.clear)
                        )
                    }
                }
            }
            .padding(6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            )
            .padding(.bottom, 22)
        }
    }
}
