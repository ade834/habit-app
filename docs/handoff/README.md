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
- `screenshots/06_h1_review_tool.png`：H1 三段式复盘、有效字数与补录入口
- `screenshots/07_h2_focus_tool.png`：H2 30分钟深度思考计时器
- `screenshots/08_h3_challenge_tool.png`：H3 每日挑战卡、换一次与完成确认
- `screenshots/09_h4_disconnect_tool.png`：H4 15/30/60分钟断网仪式选择
- `screenshots/10_habit_tools_today.png`：四个工具版本的正式默认入口今天页
- `screenshots/11_h4_auto_countdown.png`：H4 无暂停、自动完成与离页重置说明

## 四个习惯工具验证

2026-08-05，在 iPad Pro 13-inch (M4) iOS 18.6 模拟器定向构建验证：

- H1 去除标点和空格后满100字才可提交；可选今天及前3天，补录只保存不积分。
- H2 使用持久化时间戳派生专注时长；满30分钟且累计暂停不超过5分钟才完成。
- H3 由 AI 生成 500 条成长挑战，覆盖沟通、边界、行动、探索、诚实、专注、学习、关系、生活与整理；前3次换卡每次从语料库取一张新挑战，第4次起只在这3张中循环，状态关闭重开后保留。
- H4 可选15/30/60分钟，无暂停；以时间戳计算倒计时，归零后自动完成并发放积分；离开页面或 App 失去前台即作废重置，连续3次后失败并从第3次失败时刻起冷却10小时，不因跨过零点提前解锁。
- 有效完成统一走 HabitLog + PointTransaction 单事务，沿用当日防重复规则。

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
