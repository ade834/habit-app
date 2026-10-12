# M0 视觉母版

本原生壳的唯一视觉与交互母版为 S1：

`http://127.0.0.1:8765/habit-goal-card-picker.html?v=95`

其静态源文件位于：

`/Users/deshiru/Documents/Codex/2026-08-25/skill1-ui-ux-pro-max-ai/outputs/habit-goal-card-picker.html`

本阶段只实现 M0 与 M1：iPhone SwiftUI 壳和未选择目标的 S1 首页。`GoalRepository` 是内存 mock；不接 Flutter、Drift、数据库或真实提交流程。

S1 的动态母版同样来自上述网页：四个光体、主光体面积交换、碰撞混色、18.4 秒整体漂移，以及三张首页预览每 3.6 秒下沉 7pt 的折叠提示。SwiftUI 在“减弱动态效果”开启时固定为静态最终状态。
