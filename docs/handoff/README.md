# Mac / iOS 验收交接（给大 C）

更新时间：2026-08-05

## 当前结论

- 项目已从 Windows 迁移到 Mac，并以 `origin/main` 为唯一同步基准。
- Flutter 3.41.9、Dart 3.11.5、Xcode 16.4、CocoaPods 1.16.2 已验证。
- `flutter analyze` 通过；4 项自动测试通过。
- iOS 18.6 模拟器构建并运行通过。
- iPad Pro 13-inch (M4) 真机已配对，Release 包签名、安装和启动通过。
- 阶段1体验评审已通过；iPad 真机四步验收已通过，进入阶段2核心正反馈循环。

## 已验收流程

- 首次选择页：4 项习惯，可选 1～3 项，承诺文字可填写。
- 保存后进入五页主界面：今天、习惯、养成物、复盘、设置。
- 设置页提供“清除本地数据并重新开始”，带确认弹窗，确认后回到首次选择页。
- SQLite 数据关闭并重开后仍保留；重复打卡不会重复积分。

## 截图

- `screenshots/01_onboarding.png`：首次选择页
- `screenshots/02_settings_reset_confirm.png`：设置页清除数据确认弹窗
- `screenshots/03_today.png`：主页面今天页
- `screenshots/04_ipad_onboarding_selected.png`：iPad 真机首次选择页（已选择两个习惯并填写原因）
- `screenshots/05_ipad_today_checked.png`：iPad 真机今天页（习惯卡、完成状态与积分）

## iPad 真机验收记录

2026-08-05，用户在 iPad Pro 13-inch (M4) 上完成验收：

1. 选择两个习惯、填写“我想养成这些习惯，是因为……”并点击“开始养成”。
2. 今天页显示两张习惯卡，并提供“完成”按钮。
3. 完成打卡后积分发生变化。
4. 强制退出并重新打开 App，习惯和打卡记录仍然保留。

结论：iPad 验收通过，可进入阶段2。

## 读取顺序

先读根目录 `AGENTS.md`、`docs/CURRENT.md`、`docs/MAC_HANDOFF.md`，再看本文件和 `screenshots/`。大 C 只做规格与体验评审，不修改 `app/` 代码。

## 安全说明

仓库包含当前开发用 Bundle ID `com.deshiru.habitApp` 和 Team ID `KLQ45Z6A29`，用于 Mac 复现签名配置；签名证书私钥、`.p12`、Provisioning Profile 和 Apple 登录令牌均未上传。
