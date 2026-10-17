# POSY 主 App 集成

## 交接区

- 本次交接编号：`PH-20261016-GARDEN-MAIN-01`
- 源交接编号：`PH-20261016-GARDEN-01`
- 交接状态：材料已核对，等待接手核验
- 工作目录：`/Users/deshiru/Documents/ChatGPT/习惯 app`
- 分支：`codex/today-page`
- 更新时间：2026-10-16（Asia/Shanghai）
- 未提交改动：保留在当前工作树；不要 reset、clean、提交或推送
- 接手第一步：只读检查本文件、`GardenView.swift`、`GardenStudioView.swift` 和 `HabitGardenDatabase.swift`，再运行构建与数据测试

- 用户在 2026-10-16 明确授权将 Antigravity 庭院完整迁入当前养成物页，包括入场动画；本次授权覆盖旧的 Garden / GrowthView 文件隔离约定，仅改当前工作树。
- 来源：`/Users/deshiru/Documents/ChatGPT/HabitNative-antigravity`，`PROJECT_STATE.md` 编号 `PH-20261016-GARDEN-01`。
- 原始六个 POSY 文件新增到当前 Garden 目录；只对当前副本增加数据库、点击选择与嵌入模式接口。源工程不改。
- 保留 `GrowthView(goals:)` 包装、液态光球背景、原进度卡和分页指示、ContentView 底部导航。项目使用文件系统同步 target，新 Swift 文件无需更改工程文件。
- H1–H12 按 POSY `titleZh` 的 1–12 号映射，注意金琥珀阳为 H6，青绒蒲公英为 H7，不能按枚举声明顺序交换。
- 积分只读 `point_transactions JOIN habit_logs` 按习惯聚合；养成值复用 `goalMetrics` 和 `HabitGrowthRules` 的 0/3/10/25/60 阈值、休眠和衰减。两者分别展示，浇水按钮不再伪造积分或完成记录。
- 不更改数据库 schema、积分提交、既有成长规则或导航栏实现。

## 实现与验证

- 入口保留 `GrowthView(goals:onStartHabit:)`。新增可选任务回调；已有选择进入任务内页，未选择的习惯进入既有选卡流程，不绕过名额规则。
- `GardenStudioView(embedded:plantProgress:habitNames:onSelectFlora:onIntroVisibilityChange:)` 接受每株植物的真实养成进度。嵌入模式隐藏积分加减与阶段滑杆等演示控制台，保留入场、重播、风动、拖动、生灵、光斑和静态缓存。
- 卡片、分页指示和植物点击互相联动；标签增加习惯简称；标签宽度和位置限制在屏幕内。
- 背景由 ContentView 在整窗绘制原 `LiquidBackgroundView`，避免第二套局部背景造成矩形断层。只取消 Garden 重复的通用占位，保留 `84pt` 导航避让，未改导航栏代码。
- Debug 构建成功。Codex iPhone 17 Pro 的 XCTest 验证入场、重播、卡片横滑、点击花后切回卡片和习惯简称，1 项通过。
- 原 H1–H12 SQLite 迁移与提交规则烟测通过；独立临时数据库验证周期积分倍率、星标零积分、逐习惯积分聚合、读后刷新、休眠衰减、五个成长阈值及 12 种植物唯一映射通过。
- 不修改 Antigravity 源工程，不操作 18 Pro，不提交或推送。真实数据的低养成值按种子/幼株显示，不使用演示满级数据。

## 当前文件状态

- 已完成：六个 POSY 核心 Swift 文件复制到当前 Garden 目录，并增加嵌入模式和真实数据适配。
- 已完成：`GardenView.swift` 使用 POSY 庭院作为养成物主内容，同时保留原背景、进度卡、分页指示和底部导航。
- 已完成：`HabitGardenDatabase.swift` 从现有 SQLite 只读计算 H1–H12 的完成次数、积分、养成值和不活跃天数。
- 已完成：`GardenHabitBridge.swift` 使用显式 H1–H12 映射，避免 H6/H7 枚举顺序错误。
- 未完成：用户尚未对最终视觉效果作新的验收确认。
- 未验证：真实设备上的长时间运行性能；当前仅完成模拟器构建和交互验证。

## 验证证据

- 构建日志：`/tmp/habit-posy-integration-build.log`
- 最新截图：`/tmp/habit-posy-integrated-final.png`
- Garden UI XCTest 结果：`/tmp/HabitScrollProbe/Proof-garden-final.xcresult`
- 数据规则测试：`bash HabitNative/scripts/run-garden-data-tests.sh`
- 原生数据库烟测：`bash HabitNative/scripts/run-native-data-tests.sh`
- 结果：上述构建、数据测试和 Garden UI 测试均通过；未修改用户真实数据。

## 接手边界

- 可以继续：检查并修正当前养成物页的布局、数据展示或交互。
- 不应直接做：覆盖 Antigravity 源目录、改变数据库 schema、伪造积分/完成记录、操作 iPhone 18 Pro、提交或推送。
- 若需改变既定成长规则，先记录新的用户决定，再修改对应实现和测试。
