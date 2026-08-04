# Mac迁移与大D交接入口

> 用途：把本项目复制到Mac并由新安装的Codex接手时，避免依赖聊天记忆。  
> 新会话固定读取顺序：`AGENTS.md` → `docs/CURRENT.md` → 本文件。

## 一、接手口令

用户在Mac上的Codex中打开项目根目录后，只需说：

> 交接一下。现在在Mac上，请按三个交接文件检查环境，跑通iOS模拟器和iPad真机；不要做Android。

大D必须先执行：

```bash
pwd
git status --short --branch
git log -3 --oneline
cat AGENTS.md
cat docs/CURRENT.md
cat docs/MAC_HANDOFF.md
```

不得依赖旧聊天内容替代这些文件。

## 二、项目现状

- 阶段0产品规格已冻结且正式关闭；H2名称、判断和文案均统一为30分钟。
- 阶段1 Windows端已完成：Flutter骨架、首次选择、五页导航、Drift/SQLite、积分流水和核心测试。
- `flutter analyze`：通过，无问题。
- `flutter test`：3项通过：选择1~3项边界、重复打卡不重复积分、关闭并重开数据库数据仍保留。
- Android目录只是Flutter自动生成空壳，本阶段冻结；不要构建、测试或适配Android。
- iOS尚未在Mac编译，这是Mac端第一项任务。

关键代码：

- `app/lib/main.dart`
- `app/lib/ui/habit_app.dart`
- `app/lib/domain/habit.dart`
- `app/lib/data/app_database.dart`
- `app/test/app_database_test.dart`

## 三、固定环境口径

- Flutter：`3.41.9 stable`
- Dart：`3.11.5`（随Flutter）
- Drift与生成工具：`drift 2.33.0`、`drift_dev 2.33.0`、`sqlparser 0.44.5`
- 原因：当前Flutter SDK依赖约束下，新组合曾导致Drift生成器API冲突；Mac首次验证不要顺手升级依赖。
- Xcode：使用当前macOS支持的最新正式版，不用Beta。
- CocoaPods：若 `pod --version` 不存在，再安装；不要预先堆额外工具。

当前应用名“习惯花园”和Bundle ID前缀 `com.habitapp` 均为开发占位，上架前再由用户定正式名称。

## 四、迁移方式

当前项目尚未配置远程Git。第一次迁移最简单的方式：

1. 在Windows把整个 `E:\clauedcode\habit-app` 文件夹压缩为ZIP，必须包含隐藏的 `.git` 目录。
2. 传到Mac并解压到例如 `~/Projects/habit-app`。
3. 在Mac Codex中打开该项目根目录。
4. iOS首次验证完成后，再由大D协助建立私有Git远程，实现两台电脑同步。

如果ZIP中没有 `.git`，代码仍能运行，但提交历史丢失；应回Windows重新打包，不要在Mac重新初始化另一个仓库。

## 五、Mac端执行顺序

### 1. 环境检查

```bash
flutter --version
dart --version
xcodebuild -version
pod --version
flutter doctor -v
```

大D可处理Flutter、CocoaPods、Xcode命令行配置和模拟器下载。用户本人只处理管理员密码、Apple ID登录、Apple协议，以及iPad上的“信任此电脑”和“开发者模式”。

### 2. 项目验证

```bash
cd ~/Projects/habit-app/app
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator
open -a Simulator
flutter devices
flutter run -d <模拟器设备ID>
```

不要先执行 `flutter upgrade`、`flutter clean` 或重新生成整套工程；只有真实错误需要时才做最小修复。

### 3. iPad真机

- 数据线连接并在iPad上信任Mac。
- iPad开启“设置 → 隐私与安全性 → 开发者模式”。
- Xcode登录Apple ID，并在Runner的Signing & Capabilities中选择Team。
- 运行：

```bash
flutter devices
flutter run -d <iPad设备ID>
```

## 六、阶段1人工验收

- 首次打开显示4项习惯。
- 未选择时不能继续；可选择1~3项；第4项不能突破上限。
- 承诺文字可为空，也可保存。
- 保存后进入主界面。
- “今天、习惯、养成物、复盘、设置”五个页面均可打开。
- 完全退出并重新运行后不再出现首次选择页，SQLite数据仍在。
- 无红屏、崩溃、数据库异常或持续控制台错误。
- 不通过卸载App验证持久化，因为卸载会正常删除本地数据。

## 七、交付大C评审

用户提供：首次选择页、选择1~3项状态、五个主页面、重启后首页的截图。大C只做规格与体验评审，不修改 `app/` 代码。问题清单写入 `docs/reviews/`，再交大D修复和复测。

阶段1通过后，大D更新 `docs/CURRENT.md` 并进入阶段2核心正反馈循环。
