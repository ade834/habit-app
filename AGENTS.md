# AGENTS.md —— 习惯养成 App 项目说明(Codex 读取)

## 产品一句话目标
把《人生回报率最高的12个习惯》做成一个有养成反馈、能长期坚持的习惯养成 App。iOS 优先,Android 随后,鸿蒙二期。

## 技术栈(已定)
- Flutter(Dart),iOS + Android 一套码
- 状态管理:Riverpod
- 本地数据库:SQLite(Drift)
- 通知:flutter_local_notifications
- 国际化:flutter intl,首发中文,预留5语言(简/繁/英/日/西)
- 动画:Flutter 内建,后期评估 Rive
- AI:Claude API(服务端接口,Key不落客户端)

## 目录结构
```text
habit-app/
├─ AGENTS.md / CLAUDE.md
├─ docs/{CURRENT.md, product/, technical/, reviews/}
├─ app/          Codex维护的Flutter代码
├─ backend/      Codex维护的AI接口
└─ assets/{content/, images/}
```

## 代码风格与规则
- 单一代码负责人:**Codex 独占 `app/` 和 `backend/`,Claude 不直接改代码**。
- 核心写入用**单一事务**(打卡→streak/成长/积分一次性原子更新),事务提交成功后再广播事件给副作用订阅者(动画/通知/分析,不碰核心数据)。
- HabitLog 是唯一事实来源,streak/成长阶段/完成率尽量派生计算,不冗余存储、不重复发奖励。
- 按功能开短期分支(`feature/xxx`、`fix/xxx`),不建长期 claude-branch/codex-branch。

## Ponytail 最小化原则(写代码前必过决策阶梯)
两个 AI 均已安装 ponytail,写任何代码前按阶梯停在第一条成立处:

1. 这个功能需要存在吗? → 不需要就不写(YAGNI)
2. 本代码库里已有? → 复用,不重写
3. 标准库能做? → 用标准库
4. 平台原生特性能做? → 用原生
5. 已安装的依赖能做? → 用它
6. 一行能写完? → 一行

要求:保留全部校验/错误处理/安全/无障碍;砍的是过度设计,不是健壮性。

## 数据与隐私红线
- 本地优先,离线可用,不强制账号。
- AI 复盘默认关闭,发送前明示,API Key 只在服务端,用户可删记录,AI不可用时退回本地模板。
- 不做医疗/心理/财务诊断。

## 必须运行的检查
- 静态分析通过
- 覆盖核心规则的自动测试(重复打卡不重复发奖励、退出App后数据不丢)
- 手动走通主流程
- 构建验证

## 分工
Codex = 技术负责人+主程序员(架构/代码/测试/构建/iOS签名上架)。
Claude = 产品规格+内容+体验评审(读diff/截图,不改代码)。
用户 = 最终产品决策。
完整协作规则见 `05_协作分工方案_定稿.md`(上级目录)。

## 交接输出约定
- 每次交给 Claude（大C）评审时，Codex 除了更新交接文档，还必须单独提供一段可由用户直接转发的评审指令。
- 评审指令使用 Codex 的口吻，明确列出目标分支、最新提交、验收重点、交接材料位置、问题反馈格式，以及“通过后应如何明确回复”。
- 这段指令必须独立成段，不要求用户重新整理或补充上下文。

## 规格与任务文件位置
- 产品规格:`docs/product/`
- 当前迭代范围:`docs/CURRENT.md`
- 评审记录:`docs/reviews/`
- 新设备或新会话交接:`docs/MAC_HANDOFF.md`（读取顺序：本文件 → `docs/CURRENT.md` → `docs/MAC_HANDOFF.md`）
