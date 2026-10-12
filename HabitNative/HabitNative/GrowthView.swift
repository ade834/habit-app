import SwiftUI

// MARK: - 养成物主页面视图 (GrowthView — 程序化矢量花园与 POSY 美学)
struct GrowthView: View {
    let goals: [Goal]

    // 支持主分支无缝调用的便捷初始化方法
    init(goals: [Goal] = []) {
        self.goals = goals
    }

    var body: some View {
        GardenView(goals: goals)
    }
}

// MARK: - SwiftUI Preview
#Preview("养成物页面") {
    GrowthView()
}
