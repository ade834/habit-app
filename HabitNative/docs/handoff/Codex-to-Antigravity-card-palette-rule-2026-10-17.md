# Codex → Antigravity：卡片底色统一规则

状态：已实现；用户 2026-10-17 明确项目由 Codex 全权接管，本交接不再等待确认
日期：2026-10-17

## 用户决定

待选择卡片集以及其他习惯卡片的底色，统一从当前背景浮动光球的颜色生成：取光球调色板中最深和最浅的两种颜色，按卡片总数在两端之间等距插值，为每张卡片生成底色。此规则适用于“原色”和“雾紫”两个主题。

插值结果是卡片的基础色。现有或后续卡片表现可以继续叠加，包括渐隐、高光、阴影、饱和度和亮度调整。

## 背景光球颜色来源

- `HabitNative/LiquidBackgroundView.swift` 的 `CanvasLiquidBackground.drawFluidSpheres` 定义主光球渐变。
- 原色主题主球色板由粉色与杏橙色渐变在动画中混合、交换。
- 雾紫主题主球色板由 `HabitColorTheme.accent` 和 `companion` 生成。
- 两个小装饰球和碰撞核心也有辅助色；实现时建议仅从两个主光球的可见色板提取端点，避免透明渐变末端影响明暗排序。

## 拟修改接口与文件

- 共享文件 `HabitNative/Goal.swift`：新增可测试的卡片底色插值接口，或确认由 Codex 在 `ContentView.swift` 提供接口并避免改共享文件。请确认首选方式。
- Codex 独占 `HabitNative/ContentView.swift`、`HabitNative/TodayComponents.swift`：将统一插值色接入待选择卡片、首页预览、已选卡组、任务展开卡片和任务执行扩展层；保留卡片已有渐变、高光、阴影、透明度等装饰。
- `HabitNative/LiquidBackgroundView.swift` 属 Antigravity 独占目录以外，但背景来源应维持一个与其主球色板相同的颜色定义。若需要抽取共用调色板常量，请由 Antigravity 确认或提供接口，避免两处复制后漂移。

## 请确认

1. 是否同意此颜色规则适用于全部习惯卡片，并按每个当前卡片集合的总数等距插值？
2. 光球色板明暗排序是否采用感知亮度（而非单独 RGB 通道）？
3. 共用主球颜色是否由 Antigravity 从 `LiquidBackgroundView.swift` 提取为可访问的纯色板接口，供卡片规则调用？
4. 是否确认 Codex 可以在回复后修改共享 `Goal.swift`（若采用该实现）？

## Antigravity 回复区

此交接区已由用户的项目接管决定取代，无需回复。实现记录：

- 主光球纯色停靠点由 `HabitColorTheme.floatingOrbSpherePalettes` 提供，背景渐变与卡片采样共用。
- 卡片按感知亮度找出主光球色板两端，再按当前卡片集合顺序均匀插值。
- 规则同时用于原色和雾紫主题；底色之后继续叠加主题映射、渐变、高光、透明度和阴影。
- 项目协作规则记录在 `HabitNative/AGENTS.md`。
