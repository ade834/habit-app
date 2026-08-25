# 交接指令(给大D/Codex)· 阶段3 合并 main + 上线前清理

> 用户已 iPad 真机验收通过 9d86d0b 之前的版本,并在本轮 0f0e1fa 最终语义上逐项拍板(见 docs/reviews/07_阶段3最终复核_大C.md 第七节):周期跨周期重新占名额、星标上限 1/2、AI 本地预览保留、自动记错过保留。
> 大C 最终结论:**通过,允许合并**。无阻塞项。

## 一、合并 main

- 你当前在 `feature/stage3-local`(HEAD 应为大C 复核文档提交 `f006c3f` 之后的最新)。
- 合回主分支:`git fetch origin && git checkout main && git pull origin main`,然后 `git merge feature/stage3-local`(普通合并即可,不要改写历史),处理冲突后 `git push origin main`。
- 合并前请确保 `feature/stage3-local` 上确实包含 `0f0e1fa` 及之后大C 的文档提交(`docs/reviews/07_阶段3最终复核_大C.md` 应在树里)。

## 二、合并前/同时清理调试项

1. 设置页 `kDebugMode` 调试测试点:加积分(+1/+5)、调试测试日期入口——移除或仅限 debug 构建藏入测试页,正式 Release 不可见(当前测试开放版 UI 里不应有入口)。
2. 若有其他测试期专用 UI(如 enable 测试日期同步复用),一并确认是否随发布条件隐藏。
3. 仓库里不要留下任何真实 API key;AI 建议当前为本地预览(PreviewMonthlyInsightGenerator),**正式接入服务端 AI 另行立项**(需代理 + 隐私政策 + App Store 数据披露),不在本次合并范围内。

## 三、验收

- `flutter analyze` 通过;`flutter test` 全过;iOS Simulator Debug 构建通过。
- 用户会在 iPad 真机上做最终一次走过场复验(使用合并后的 main)。

## 四、回复格式

完成后按"已完成项 / 验证结果 / 遗留问题"回复,并给出合并后的 `main` 最新提交号,写入 `docs/handoff/给大C_最新回复_大D.md` 并推送。
