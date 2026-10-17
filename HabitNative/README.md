# HabitNative

原生 SwiftUI 习惯应用。打开 `HabitNative.xcodeproj`，选择 `HabitNative` scheme。
当前部署目标为 iOS 27.0，需要提供该 SDK 的 Xcode。

## 构建与验证

```sh
xcodebuild -project HabitNative/HabitNative.xcodeproj -scheme HabitNative -configuration Debug -destination 'generic/platform=iOS Simulator' build
bash HabitNative/scripts/run-native-data-tests.sh
bash HabitNative/scripts/run-garden-data-tests.sh
```

以上命令从仓库根目录执行。测试使用临时数据库，不修改用户数据。

## 项目结构

- `HabitNative/`：应用入口、今日卡片、任务执行、复盘和 SQLite 数据层。
- `HabitNative/Garden/`：12 种植物、花头渲染、生长规则和花园交互。
- `HabitNative/AppFoundation/`：设计基础与系统集成。
- `scripts/`：原生数据与植物映射测试。
- `server/`：仅供本机开发的千问复盘代理。

## 2026-10-18 更新

今日选择卡片复用习惯对应植物的最终阶段花头（`progress = 1`）。
花头采用统一的 300 × 300 点画布（上版 600 点的 0.5 倍），居中叠放在原有 104 点圆圈上。
花头饱和度为原值的 75%，亮度增加 0.15，整体不透明度为 50%；圆圈、布局与选择手势保持不变。
卡片花头固定相位，不启动花园动画计时器。

数据库当前版本为 16。迁移按表名定位建表语句，避免新增表后数组索引错位。
已增加旧库迁移后的版本与表完整性检查，并清理无用变量及错误的源码执行权限。

## 本地复盘服务

```sh
zsh HabitNative/server/start_local_qwen_proxy.sh
```

代理只监听 `127.0.0.1:8765`。API 密钥从 macOS 钥匙串读取，服务名为
`com.deshiru.habitapp.qwen`，账户名为 `dashscope-api-key`。
仓库不保存密钥或用户数据库。当前周/月 AI 复盘依赖本机代理，真机发布前需配置可访问的后端。

`outputs/` 截图、录屏、模拟器临时文件和本地数据库不纳入版本控制。
