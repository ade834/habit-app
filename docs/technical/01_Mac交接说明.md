# Mac 交接说明(致大D)

> 2026-08-05。协作环境从 Windows 转到 Mac。本文件是一次性交接,之后以仓库内文档为准。

## 一、仓库(唯一事实来源)

- 地址:https://github.com/ade834/habit-app(**私人仓库**,账号 ade834)
- Mac 首次拉取:

```bash
git clone https://github.com/ade834/habit-app.git
```

首次需 GitHub 授权(`gh auth login` 或 token)。

## 二、分工(不变,细则见根目录 `05_协作分工方案_定稿.md`)

- **用户** = 最终产品决策。
- **大C**(Claude,仍在 Windows)= 产品规格、文案、体验评审。**不改代码**,只读 diff/截图提意见。
- **大D**(Codex,现在 Mac)= 技术负责人,**独占 `app/` 和 `backend/` 代码**、测试、构建、iOS 签名上架。

## 三、当前进度

- **阶段0 已关闭**:规格冻结,见 `docs/product/01_第一阶段产品规格.md`;评审记录 `docs/reviews/01_第一阶段规格技术评审_大D.md`。关键决策:H2=30分钟(暂停上限5分钟)、休眠恢复=3个不同自然日、积分第一阶段做(每日首次有效完成1分,流水同事务)、挑战卡无条数硬指标。
- **阶段1 骨架完成**,Windows 端验收通过(flutter analyze 干净、测试覆盖首次选择+重复打卡防重)。
- **iOS 验证未做**——Windows 做不了,这正是转 Mac 的原因。

## 四、大D在Mac立即要做的事

1. `git clone` 仓库。
2. Flutter 环境检查(`flutter doctor`),确认 Xcode、模拟器可用。
3. 跑 iOS 模拟器/真机首次验证:五个页面(首页/习惯/养成物/复盘/设置)能打开、首次启动选1~3习惯+写承诺文字、重启后数据仍在。
4. 给用户试跑,截图发大C评审。
5. 评审通过 → 进**阶段2:核心正反馈循环**(打卡→积分→养成物成长→阶段进度→第二章解锁判定)。

## 五、同步规则(重要)

- **origin/main 是唯一基准**。开工先 pull,改完 push,别让本地和线上分叉。
- 大C在 Windows 侧也会读写此仓库(docs、文案、评审),push 前必先 pull,避免冲突。
- 代码类文件(`app/`、`backend/`)只有大D动;`docs/product/` 只有大C动;`docs/reviews/` 双方都可写。

## 六、必读文件

| 文件 | 干什么用 |
|---|---|
| `AGENTS.md` | 项目规则/技术栈/ponytail原则(Codex自动读) |
| `docs/CURRENT.md` | 当前迭代范围/验收条件/已知问题 |
| `05_协作分工方案_定稿.md` | 三方协作全流程 |
| `docs/product/01_第一阶段产品规格.md` | 冻结的产品规格,实现唯一依据 |
| `assets/content/localized/` | 五语言文案(i18n 内容源) |

## 七、已知问题(摘自 CURRENT.md)

- 应用名"习惯花园"、包名 `com.habitapp` 是占位,上架前用户定正式名和 Bundle ID。
- drift/drift_dev 2.33.0、sqlparser 0.44.5 被 Flutter SDK 依赖约束锁定。
- 阶段1不构建、不测试 Android。
- MacBook Pro 2019(Intel)+ iPad M4 2024 做构建和真机测试,无需云CI。
