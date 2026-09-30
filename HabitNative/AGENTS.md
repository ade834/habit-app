# HabitNative 项目工作偏好与行为规范

## 1. 完成即在 Device Hub 中刷新并打开（核心规则）
- **每次代码改完后立即在 Device Hub 模拟器中刷新并打开前台**：每当完成任何 UI 或逻辑改动，直接编译部署至已启动的模拟器，重新唤起 App，并调用 `open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"` 将 Device Hub 唤醒激活并置于前台，同时生成最新截图展示给用户，确保用户屏幕上直接显示 Device Hub 的实时运行状态！
- **免手动确认编译**：自主调查并解决编译与运行时报错，无需中断等待用户手动在 Xcode 点击运行。

## 2. 设计与工程规范
- 严格遵循 `taste-skill`、`finesse-ui` 与 `ui-ux-pro-max` 规则，保持高审美质感、克制的呼吸感以及移动端手势流畅度。
- 遵循原母版视觉节奏，杜绝通用塑料感 AI 界面。

## 3. Strict Module Ownership（严格模块物理文件隔离契约）

### 3.1 Codex 独占写入权
- Codex 独占负责 `HabitNative/ContentView.swift` 和 `HabitNative/TodayComponents.swift`。
- 负责范围包括：“今日（Today）”页面的卡片、选择交互、确认与数据回读、常驻底部液态导航栏、设置展开面板以及这些功能在上述两个文件中的实现。
- Antigravity 不得修改上述两个文件。需求变更通过 `docs/handoff/` 中的交流文件传递。

### 3.2 Antigravity 独占写入权
- Antigravity 独占负责 `HabitNative/Garden/` 目录下的全部文件以及 `HabitNative/GrowthView.swift`。
- 负责范围包括：养成物页面、程序化矢量花卉引擎、生长阶段算法、花器交互和横滑进程走马灯。
- Codex 不得修改这些文件；只能读取它们以确认公共接口与编译集成状态。

### 3.3 唯一集成契约
- 当 `ContentView.swift` 切换到“养成物” Tab 时，仅通过 `GrowthView(goals: goals)` 包装组件接入养成物页面。
- 由 `ContentView.swift` 在外层负责 `.padding(.bottom, 84)`，为底部液态导航栏留出避让高度。
- `GrowthView` 不得反向修改、复制或接管底部导航；`ContentView` 不得内联养成物页面的具体 UI。
- 在 `GrowthView.swift` 存在并且公开初始化接口可编译前，Codex 不得提前写入对 `GrowthView` 的调用。

### 3.4 共享文件变更
- `Goal.swift`、`SharedHabitSelectionStore.swift`、`HabitGrowthRules.swift`、`HabitNativeApp.swift`、项目工程文件以及资源目录视为共享边界。
- 任一 Agent 如需修改共享边界，必须先在 `docs/handoff/` 记录修改理由、接口差异和影响文件，等待另一方确认后再动手。
- 禁止通过整文件覆盖、回滚或从其他工作目录复制的方式合并代码；只允许基于当前版本进行最小化差异集成。
