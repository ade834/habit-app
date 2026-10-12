# Codex → Antigravity：习惯详情表单与数据库写入契约

状态：原生数据层与一次性迁移已实现并完成模拟器验证
日期：2026-10-11

## 目标

用户确认最终只保留原生 SwiftUI App，不要求 Flutter 与 SwiftUI 长期共享数据库。需要把 Flutter Habit App 的数据模型、规则与持久化行为迁入原生项目，完成等价验证，并将旧库做一次性迁移到原生 App 的独立数据库。当前仅在 Codex 独占的 `ContentView.swift` 中完成表单展示与卡片展开转场；输入暂存于页面状态，未写入数据库。

## 已核对的 Flutter 规则与字段

- H1：复盘日期、决定、结果、改进；三项有效字符合计至少 100；写入 `review_entries`，并根据当天规则记录完成日志。
- H2：推荐/自定义思考主题、30 分钟专注计时；计时会进入 `timer_sessions`，完成后记日志。
- H3：每日挑战抽卡/换卡，完成时记 H3 完成日志。
- H4：睡前断网计时，使用 H4 计时/完成规则。
- H5：`primaryText=联系了谁`、`secondaryText=你们聊了什么`，按周写入 `habit_activity_entries`。
- H6：`primaryText=清理了哪个信息源`、`secondaryText=为什么`，按日写入 `habit_activity_entries`。
- H7：`primaryText=本周最大的财务发现`、`secondaryText=下周调整`、`firstValue=资产投入`、`secondValue=消费消耗`，按周写入 `habit_activity_entries`。
- H8：`primaryText=拒绝了什么`、`secondaryText=守住的边界`，按日写入 `habit_activity_entries`。
- H9：`primaryText=这次输出讲清了什么`、`secondaryText=你能讲给我听么`，按日写入 `habit_activity_entries`。
- H10：`primaryText=读完的跨界书`、`secondaryText=最重要的收获`，按月写入 `habit_activity_entries`。
- H11：旅行计划字段为目的地、天数、焦点、准备事项，写入 `travel_plans`；旅行回来后单独提交回顾并完成活动记录。
- H12：`primaryText=今天必须承认的真话`、`secondaryText=明天采取的行动`，按日写入 `habit_activity_entries`。

补充交互/校验规则：

- H5–H10、H12 的主文本当前最多 5 字；主文本必填，副文本选填。H7 两个金额字段选填，但非空时必须可解析为数字。H11 使用独立旅行向导，不受该主文本长度限制。
- H1 只允许今天或前 3 个自然日补录；中文有效字数按 Unicode 字符统计并排除空白和标点，达到 100 字才完成。补录只写复盘，不得补发积分。
- H2 每天推荐 3 个议题，也可自定义；专注目标 30 分钟，暂停总时长超过 5 分钟不算完成。
- H3 每日保留抽卡结果；前 3 次换卡给新挑战，此后在已有前三张挑战间循环。
- H4 可选 15/30/60 分钟，不可暂停；离开 H4 页面或 App 重启会使未完成会话失败，锁屏/通知中心/切换 App 不会中断；连续失败 3 次后冷却 10 小时。
- H11 首次进入保存本年度旅行计划（天数 1–30、目的地和旅行重点必填）；再次进入填写旅行总结后才完成本年任务。
- 日常新完成以 `habit_id + local_date` 幂等；已有完成不会重复发积分。普通任务 1 分、H5/H7 每周 3 分、H10 每月 4 分、H11 每年 99 分；星标完成仍记日志/成长，但积分为 0。
- 周期习惯是 H5/H7（周，周一为周期起点）、H10（月）、H11（年）；周期内可暂存到之后完成，并在实际完成日记日志。周期完成后，在当前周期里不再重复出现。
- 普通习惯最多 3 项；星标额外计数且第一阶段最多 1 个，累计有效完成 6 次后第二阶段永久解锁，星标上限变为 2。周期习惯次日自动保留且不占普通名额；跨周期重新选择时会占当天名额。
- 全局成长按 0/3/10/25/60 推进；连续 7 个完整自然日无任何完成后休眠，休眠后进度按每日 1、2 交替衰减；恢复首日立即冻结衰减，3 个不同自然日完成后退出恢复期。

字段与规则来源：真实 Flutter 仓库 `app/lib/ui/habit_tools_page.dart`、`app/lib/data/app_database.dart`、`app/lib/domain/habit.dart`。具体周期 key、补录限制、积分和完成行为应复用数据库层现有实现，不在 SwiftUI 重写。

## 当前 SwiftUI 数据缺口

- `GoalRepository.submit(_:)` 的 `SharedHabitRepository` 和 `InMemoryGoalRepository` 实现均为空。
- `GoalEntry` 仅有 `goalID/date/text`，不能表达 H1 三字段、H7 两个数值、H11 旅行计划或 H2/H3/H4 的专属流程。
- `SharedHabitRepository` 与 `SharedHabitSelectionStore` 当前都直连 App Group 的 `group.com.deshiru.habitapp/habit_app.sqlite`。SwiftUI 现在实际上与 Flutter 共用同一文件，且选择页会写入该文件；这与用户确认的最终目标不同。
- 详情页尚未调用旧规则；现有 `HabitGrowthRules` 与选择状态也需逐项对照 Flutter 实现。

## 已确认的迁移方向

1. 原 Flutter/Drift 代码作为行为与数据定义的唯一参照，不把 Dart/Drift 源码复制进 Swift target。
2. 原生侧用 Swift + SQLite 实现同样的表字段、周期 key、校验、事务、幂等、积分和 H1–H12 专属流程；UI 只通过原生 repository/service 读写。
3. 为规则建立覆盖旧行为的测试矩阵，至少包括重复完成不重复得分、周期边界、星标积分、H1 字数/补录、H2 计时暂停、H3 抽换挑战、H4 失败锁定、H11 年度计划和积分、重启后数据保留。
4. 一次性迁移时，用 SQLite backup API 从旧 App Group 数据库生成一致快照，导入到 SwiftUI App 私有 Application Support 数据库。验证表行数、关键聚合值和 `PRAGMA integrity_check` 后写入迁移完成标记；旧库保持不变，原生 App 后续只访问私有库。

不要在两个 App 运行时进行双向同步。迁移失败时保留旧库并显示可恢复错误，不设置已完成标记；重复执行必须幂等。

## 已确认的共享接口改动

Antigravity 已确认迁移边界和共享文件授权。Codex 按最小差异修改共享数据接口与 app composition root。提交 API 按 Habit ID 分流并覆盖结构化字段；H2/H3/H4 使用计时/挑战数据，不以普通文本代替。接口返回成功/校验错误，保留原周期键、补录、积分和幂等规则。SwiftUI 通过 repository/data service 访问 SQLite。

已授权共享文件：`Goal.swift`（结构化 payload 与 repository）、`SharedHabitSelectionStore.swift`（原生私有库）、`HabitGrowthRules.swift`（规则）和必要时 `HabitNativeApp.swift`。新增源文件：`NativeDatabase.swift`、`NativeHabitRepository.swift`、`HabitTaskCatalog.swift`、`HabitExecutionView.swift`。Codex 不修改 Garden/GrowthView，也不改 Flutter 源仓库。

迁移来源表共 9 张：`habit_selections`、`habit_logs`、`point_transactions`、`review_entries`、`timer_sessions`、`challenge_draws`、`habit_activity_entries`、`travel_plans`、`missed_habit_records`。旧 Drift schemaVersion 为 10；导入要保留主键、唯一约束、时间戳和外键关系。原库使用 App Group `group.com.deshiru.habitapp`；导入期间只读，完成后原生 repository 全部改用私有库。

旧仓库验收基线覆盖 `app/test/app_database_test.dart`、`app/test/habit_tools_test.dart`、`app/test/habit_growth_test.dart`。本轮在未修改旧仓库的情况下，`flutter test` 通过（50 项），`flutter analyze` 通过。迁移后为 Swift 添加等价测试；以同一组固定时间和输入分别运行旧/新实现，比较结果而非仅检查截图。

## Codex 实施与验证记录（2026-10-11）

- 完成原生 Application Support 私有 SQLite 库、SQLite Backup API 一次性导入、schema v10 升级、迁移标记和行数/聚合校验；原 App Group 库仅作为只读迁移源。
- 完成 H1–H12 的结构化提交与原生持久化流程；`Goal` 向 `GrowthView` 提供真实完成次数与成长阶段。`GrowthView(goals: goals).padding(.bottom, 84)` 接口保持不变。
- `HabitGrowthRules` 的当前实现与 Flutter 成长/休眠规则核对一致，因此没有改动该文件；App composition 由共享私有数据库路径自动连接，也无需额外注入。
- Swift 数据层烟测通过，覆盖 SQLite 迁移完整性、重复导入保护及 H1–H12 边界行为；iPhone 17 Pro 模拟器的旧库/私有库 9 张表行数相同，积分合计均为 124，`PRAGMA integrity_check` 均为 `ok`。
- `xcodebuild clean build` 成功，应用已安装并启动。构建仍显示 Garden 目录中既有警告；该目录及 `GrowthView.swift` 未修改。
