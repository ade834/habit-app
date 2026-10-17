import SwiftUI

// MARK: - 养成物主页面视图 (GrowthView — 程序化矢量花园与 POSY 美学)
struct GrowthView: View {
    let goals: [Goal]
    let onStartHabit: ((Goal) -> Void)?
    let onIntroVisibilityChange: ((Bool) -> Void)?
    let onSharePhoto: ((UIImage) -> Void)?

    // 支持主分支无缝调用的便捷初始化方法
    init(
        goals: [Goal] = [],
        onStartHabit: ((Goal) -> Void)? = nil,
        onIntroVisibilityChange: ((Bool) -> Void)? = nil,
        onSharePhoto: ((UIImage) -> Void)? = nil
    ) {
        self.goals = goals
        self.onStartHabit = onStartHabit
        self.onIntroVisibilityChange = onIntroVisibilityChange
        self.onSharePhoto = onSharePhoto
    }

    var body: some View {
        GardenView(
            goals: goals,
            onStartHabit: onStartHabit,
            onIntroVisibilityChange: onIntroVisibilityChange,
            onSharePhoto: onSharePhoto
        )
    }
}

// MARK: - SwiftUI Preview
#Preview("养成物页面") {
    GrowthView()
}
