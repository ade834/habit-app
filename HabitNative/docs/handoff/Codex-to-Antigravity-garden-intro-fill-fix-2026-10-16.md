# 养成物开场过渡：远景白边与底部未填满

## 已复现

在 Device Hub 的 iPhone 17 Pro 模拟器中重播开场动画后可稳定复现：

1. 门内远景在推进时出现大块白边。
2. 静态远景切换到实时场景前，底部导航上方出现白带；画面底部看起来错位或没有填满。

## 根因

两个问题都在 `HabitNative/Garden/GardenStudioView.swift`：

- 约第 187 行：`cachedStageSnapshot` 使用 `.scaledToFit()`。快照与当前过渡容器的高度不同，按比例适配后保留了空白区域。
- 约第 108 行：嵌入式开场阶段在整个 Garden Studio 画布放置 `Color.white`。`ContentView` 同时为常驻底部导航预留了 84 pt，导致过渡层与下方预留区不是同一背景。

## 最小修复

1. 将快照改为覆盖容器：

```swift
Image(uiImage: snapshot)
    .resizable()
    .scaledToFill()
    .frame(width: canvasWidth, height: canvasHeight)
    .clipped()
```

这样静态远景会完整盖住可见画布，不会露出白边。

2. 开场静态阶段不要把 Garden Studio 的底色设为 `Color.white`。改为 `Color.clear`，让 `ContentView` 的 `TodayAmbientBackground` 一直铺满到屏幕和底部导航下方：

```swift
if embedded {
    Color.clear.ignoresSafeArea()
} else {
    PosyLiquidEtherealBackground().ignoresSafeArea()
}
```

白色闪光仍由 `PosyCinematicDoorIntroView.whiteBloomOpacity` 在门扉层绘制，因此不会改变穿门时的白闪。

## 验证

1. 反复点击“重播入场”。
2. 在远景、推进、白闪消退和实时舞台四个时刻截图。
3. 确认门内远景无白边，底部导航上方没有白带，场景背景连续铺满。
4. 完成后执行 iOS Debug 构建与 Garden 数据测试。

## 写入边界

此修复只涉及 `HabitNative/Garden/`，属于 Antigravity 独占目录。Codex 未修改该目录。
