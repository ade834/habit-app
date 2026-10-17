# 养成物页：大风按钮

## 请求

在养成物内页增加一个小按钮。点击后控制大风吹动植物。

## 写入边界

此功能只改动 `HabitNative/Garden/GardenStudioView.swift`，属于 Antigravity 独占目录。Codex 未修改该目录。

## 已核对的现有能力

- `triggerSimulatedWindGust(duration:direction:)` 位于 `GardenStudioView.swift` 约第 1044 行。
- 它已经能模拟一次强风，并在结束后保留自然回弹。
- 非嵌入式控制台已有相同能力的测试按钮；嵌入式养成物页没有可见入口。

## 建议实现

1. 在 `topHeaderBar(safeAreaTop:)` 的右侧 `HStack` 中，放在“重播入场”按钮旁。
2. 新按钮使用 `Image(systemName: "wind")`，文案为“吹风”。
3. 点击调用 `triggerSimulatedWindGust(duration: 2.2, direction: 1.0)`。
4. 复用“重播入场”胶囊的颜色、阴影和内边距。确保点击区域至少为 44×44 pt；视觉胶囊可以更小，但需扩大命中区域。
5. 在 `isPressingBlank` 为真时，显示“吹风中”，并禁用重复点击。
6. 保持它只在 `introProgress >= 0.90` 后出现，和顶部栏一致。

## 验证

- 在 Device Hub 的养成物 Tab 点击“吹风”，确认植物、粒子和背景微球均出现强风反应。
- 等待约 2.2 秒，确认风停止后出现自然回弹。
- 确认按钮不遮挡顶部标题、灵动岛或底部导航。
