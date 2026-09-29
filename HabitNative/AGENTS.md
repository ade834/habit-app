# HabitNative 项目工作偏好与行为规范

## 1. 完成即在 Device Hub 中刷新并打开（核心规则）
- **每次代码改完后立即在 Device Hub 模拟器中刷新并打开前台**：每当完成任何 UI 或逻辑改动，直接编译部署至已启动的模拟器，重新唤起 App，并调用 `open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"` 将 Device Hub 唤醒激活并置于前台，同时生成最新截图展示给用户，确保用户屏幕上直接显示 Device Hub 的实时运行状态！
- **免手动确认编译**：自主调查并解决编译与运行时报错，无需中断等待用户手动在 Xcode 点击运行。

## 2. 设计与工程规范
- 严格遵循 `taste-skill`、`finesse-ui` 与 `ui-ux-pro-max` 规则，保持高审美质感、克制的呼吸感以及移动端手势流畅度。
- 遵循原母版视觉节奏，杜绝通用塑料感 AI 界面。
