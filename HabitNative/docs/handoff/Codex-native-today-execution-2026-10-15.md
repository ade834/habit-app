# Codex 原生习惯 App：今日卡片与任务内页交接

<!-- CODEX-HANDOFF-BEGIN PH-20261015-habit-native-01 -->

## 交接状态

- 编号：`PH-20261015-habit-native-01`
- 更新：2026-10-15 12:37（Asia/Shanghai）
- 状态：当前任务已接手；H4 失活规则已按数据契约修正并完成构建和隔离数据验证。
- 源任务编号：未确认。接手任务编号：未创建。
- 用户授权范围：继续在当前 Codex 工作树开发原生习惯 App；Codex 使用 17 Pro 模拟器，Antigravity 使用 18 Pro。当前用户已授权“先只读核对工作树，再继续”；仍未授权提交、推送、切换工作树或新建聊天。

## 项目和权威资料

- 当前工作树：`/Users/deshiru/Documents/ChatGPT/习惯 app`，分支 `codex/today-page`。另一份 `/Users/deshiru/Documents/习惯 app` 是不同工作树，不要切换或复制覆盖。
- HEAD：`22e501c944e66c5e38b8f00d2cf8c72871bffa87`，2026-10-12 的 “Fix today selection quota and card star touch targets”。更早的重要提交：`3b37777`（原生任务流程）、`a753c64`（设置中的数据重置）。
- 先读 `HabitNative/AGENTS.md`：Codex 独占 `ContentView.swift`、`TodayComponents.swift`；Antigravity 独占 `Garden/`、`GrowthView.swift`。共享文件更改按该文件的交接约定处理。
- `HabitNative/docs/handoff/Codex-to-Antigravity-habit-entry-database-contract.md` 记录 Flutter 规则、原生 SQLite 迁移、H1–H12 的数据契约；`Codex-daily-selection-quota-2026-10-12.md` 记录当天名额和星标；`Codex-to-Antigravity-GrowthView-integration.md` 记录养成物接口。
- `HabitNative/MOTHER_REFERENCE.md` 记录早期 M0/M1 母版。它仍写着内存 mock、未接数据库；与目前已实现的原生持久化阶段不同。接手时按当前代码和较新的数据库交接记录核对，不把早期阶段描述当成当前完成状态。
- 当前文件系统没有项目根目录 `AGENTS.md`；本聊天另有用户提供的简短中文写作偏好。

## 未提交工作树，必须保留

- 保存交接前，`git status` 有 30 个已跟踪修改和 7 个未跟踪路径；本交接文档新增后，未跟踪路径变为 8 个。全部未提交。不要 `reset`、`clean`、覆盖、批量格式化或擅自提交。
- 有实质内容差异的已跟踪文件：`HabitNative/HabitNative/ContentView.swift`（今日已选卡片、转场、样式）、`HabitNative/HabitNative/HabitExecutionView.swift`（任务内页、计时、轮盘、完成动效）、`HabitNative/HabitNative/TodayComponents.swift`（已完成任务标识及防取消）、`HabitNative/HabitNative/Goal.swift`（从持久化星标集合映射 `isStarred`）。
- 其余已跟踪修改是文件模式 `100644 → 100755`，内容差异为零，其中含 Antigravity 的 `Garden/` 和 `GrowthView.swift`。不要仅因模式变化清理它们。
- 未跟踪路径：`.DS_Store`、`HabitNative/HabitNative/AppFoundation/`、两套 `HabitCardBackground*Preview.imageset/`、`HabitNative/HabitNative/ReviewPage.swift`、`HabitNative/current_sim.png`、`garden-spec.md`。先盘点归属，不删除。

## 用户已确认的方向

- 原 Flutter 版用作规则与逻辑参照；当前开发对象是 SwiftUI 原生版。原生数据库保留 H1–H12 的完成、周期、积分、星标和任务计时规则。
- 今日已选卡片与内页用同一任务 ID 取得底色或未来的背景图片；内页标题保持半透明白色。任务完成后播放按钮回弹和彩点，再返回已选卡片集。
- 睡前断网 H4：选 15/30/60 分钟；开始与完成共用底部按钮。计时中按钮显示灰色“完成断网”且不可手动点。无打断且计时结束时自动提交完成并返回卡片集。离开 H4 页面或重启 App 记失败；连续失败 3 次冷却 10 小时。较早的数据契约同时写明锁屏、通知中心和切换 App 不应中断，详见下方待核对项。
- 分钟选择使用上下轮盘：中间字号最大、最亮、无阴影；上下缩小、变灰并带纵深；选项之间用渐变短竖虚线连接。

## 当前实现和验证

- `ContentView.swift` 的卡片展开标题由白色透明度约 0.82 平滑过渡到 0.75，已修正展开时短暂变黑的路径。对应入口：`executionExpansionOverlay`。
- `HabitExecutionView.swift` 的 H4 已合并底部按钮；`monitorDisconnectCompletion()` 根据计时结束、活动会话 ID 和数据库状态自动调用既有 `submit`；`interruptDisconnectTimer()` 处理离开任务页；`DisconnectDurationWheel` 替代旧分钟菜单。代码已编译，但完整 15 分钟自动完成链路**尚未实测**。
- 2026-10-15 在 Codex iPhone 17 Pro（UDID `49DCD9FC-ECE8-4301-ADE3-57539855B230`）执行 `xcodebuild`，成功；安装并启动 `com.deshiru.habitnative`。手势实测：30 分钟上滑到 60 分钟，下滑回 30 分钟。轮盘初版快速滑动跳档已修正为每次一档。
- 17 Pro 已重新打开至今日页；本次没有启动 H4 倒计时或重置数据。先前在 H4 内页看到“失败 1 次、还可再试 2 次”记录。最新截图为本机临时文件 `/tmp/habitnative-h4-scenephase-20261015-loaded.png`，跨机器不可依赖。
- 最新 `git diff --check` 无错误。没有提交、推送或合并。
- 2026-10-15 续接核对：数据契约确认锁屏、通知中心和切换 App 不应让 H4 失败。已从 `ExecutionView` 移除 `scenePhase != .active` 时调用 `interruptDisconnectTimer()` 的路径；离开 H4 页面时的 `onDisappear` 失败路径保持不变。Debug 构建成功，已安装并打开 Codex iPhone 17 Pro；隔离 SQLite 的 H1–H12 烟测通过。为保护 17 Pro 现有数据，本次没有开始 H4 计时，也没有做会产生失败记录的前后台手势测试。

## 接续第一步与验收

1. 先只读核对上述工作目录、分支、`git status`、关键代码与交接文件。不要以旧提交替换工作树，也不要碰 Antigravity 独占文件。
2. 若继续验证 H4，用隔离数据检查“开始按钮变灰 → 倒计时结束 → 数据库完成记录 → 返回卡片集”，并检查前后台不失败、离页失败和冷却边界。不要在 17 Pro 现有用户数据上为测试制造失败次数。完整时间链路当前未验证，不要写成已通过。
3. 后续任何代码修改完成后，按 `HabitNative/AGENTS.md` 编译、安装并在 **Codex iPhone 17 Pro** 的 Device Hub 前台打开，截图核对；不操作 18 Pro。验收以实际界面、持久化记录和对应规则为准。

<!-- CODEX-HANDOFF-END PH-20261015-habit-native-01 -->
