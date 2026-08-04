# 当前迭代：阶段1 —— Mac首次iOS验证

## 当前目标
阶段0正式关闭；Windows端骨架验收通过。下一步在Mac验证iOS模拟器和iPad真机。

## 本阶段范围
- Flutter 共用代码与 iOS 工程（Android目录仅保留Flutter自动生成空壳，本阶段冻结）
- Riverpod 应用入口
- 首页、习惯、养成物、复盘、设置五个主页面骨架
- 首次启动从4项习惯中选择1~3项并保存承诺文字
- Drift / SQLite 本地数据库
- 每日完成日志唯一约束、积分流水与余额查询

## 不做什么
- 不实现四项习惯的具体工具交互
- 不做积分商店、旅行、桌面宠物、AI复盘或云同步
- 不做系统级断网强制锁
- 不做最终美术和复杂动画

## 验收条件
- `flutter analyze` 无问题
- 自动测试覆盖首次选择边界与重复打卡不重复发积分
- Windows完成静态分析与自动测试；iOS模拟器、编译和真机验证转到 Mac + Xcode
- 首次选择后重启 App 仍从 SQLite 读取已选习惯

## 已知问题
- Windows不能运行苹果iOS Simulator，也不能编译iOS；阶段1代码完成后需在Mac + Xcode做第一次iOS验证。Android本阶段不构建、不测试。
- 应用名“习惯花园”和包名前缀 `com.habitapp` 暂作开发占位，上架前由用户确定正式名称和 Bundle ID。
- Drift 生成工具因当前 Flutter SDK 的依赖约束暂锁定 `drift/drift_dev 2.33.0` 与 `sqlparser 0.44.5`。

## 下一步
在Mac拉取Git项目并完成首次iOS模拟器/真机验证 → 用户试跑首次选择流程 → 大C根据截图评审 → 大D进入阶段2核心正反馈循环。

Mac接手细节见 `docs/MAC_HANDOFF.md`。
