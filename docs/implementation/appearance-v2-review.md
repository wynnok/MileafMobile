# 外观 v2 双轴审查（AV09）

- 日期：2026-11-02
- 固定点：`0b6ae57`（外观 v2 批 1 之前的提交；批 1 本体是 `4fab3c0`）
- 范围：`git diff 0b6ae57 -- . ':(exclude)docs/implementation/appearance-v2-renders'`（含批 1/批 2 代码、批 3 文档与工作区改动）
- 提交：`4fab3c0` 批 1、`656de86` 批 2、`2cb51d8` 机械格式化、`ba98eb4`／`56a796d` 交接文档
- 方式：两个子代理并行、各自独立上下文——一个沿**标准**轴（仓库成文标准 + Fowler 味道基线），一个沿**规格**轴（Spec §13、票面 AV01–AV09、ADR 0006）；本文件汇总两侧结论，不合并、不重排
- 结论：**两轴明确问题已清零**（8 条已修、3 条按「不明确」记录待确认）；`analyze` 0 issue、`dart format` 0 changed、`test` 全绿

## 一、明确问题与处置

| # | 轴 | 问题 | 处置 | 验证 |
| --- | --- | --- | --- | --- |
| 1 | 标准 / 规格 | 8 处 `InkWell.highlightColor` 仍是 `accent` 12%，§7.2（primary/ghost → `accentSoft`）、§7.4（未选行 → `accentSoft`）、§3.4（不用 accent 做填充）都不允许。批 1 记为偏离、批 2 推给「AV08 一次改完」，而 AV08 是文档票，实际无人承接 | `button.dart`、`chip.dart`、`nav_bar.dart`、`icon_button.dart`、`appearance_sheet.dart`、`metric.dart`、`workspace_page.dart`、`top_bar.dart` 全部改 `accentSoft`；`top_bar` 的 hero 分支保留 `accentHero` 12%（hero 上无 `accentSoft`）；`button` 按 kind 分流：secondary → `pressOverlay`（§7.2 明确要求），primary/ghost → `accentSoft` | `design_components_test` 新增「强调色分层」断言 pressed 高亮值 |
| 2 | 规格 | §13「所有强调色文字用 `accentStrong`」零 widget 断言——把文字改回 `accent` 测试仍绿 | `design_components_test` 新增组：导航选中标签、chip 选中标签、ghost 按钮文字 == `accentStrong`；secondary == `text`；primary == `textOnAccent`；两模式各一条 | 新断言通过 |
| 3 | 规格 | 冷启动只断言 settle 之后的亮度，§13「无先深后浅」没有守住首帧 | `appearance_shell_test` 新增「冷启动首帧即为主题亮度」：平台深色、无保存值、`pumpWidget` 后**不 settle** 直接读 `Theme.brightness` | 新断言通过 |
| 4 | 规格 | §11「主题切换 200ms」只断了 `lerp` 插值，没断 `themeAnimationDuration` | `appearance_shell_test` 的冷启动用例补 `themeAnimationDuration == 200ms` | 新断言通过 |
| 5 | 规格 | 文档把未完成当已完成：4 处链接指向还不存在的 `appearance-v2-review.md` | 本文件即目标；`appearance-v2.md` Spec 状态行与 §13 也改为指向本文件 | 链接可达 |
| 6 | 规格 | Spec §2.3 仍写 `seriesSecondary`「不变」，与 §8 的实施修正自相矛盾；ADR 0006 D5 同款 | Spec §2.3 单列「改值（实施修正）」并说明理由；ADR 0006 D5 增加 **D5.1** 修正条款（保留原文作决定记录） | 文档一致 |
| 7 | 标准 / 规格 | ADR 0003 §2 仍把「默认深色并持久化」写成规则，与 ADR 0006 D1 冲突（AV08 的 grep 验收因此不达标） | ADR 0003 §2 加行内修订说明（原文保留为历史决定）；文首已注明配色与默认外观被 ADR 0006 修订 | grep 复查 |
| 8 | 标准 | `hero.dart` 卡片光晕注释写「半径按卡片宽度计算」，实际 `RadialGradient.radius` 是**短边**比例 | 注释改为事实描述，并指出 §6.3 的「半径 ≈ w×0.95」是近似说法 | 代码注释 |

## 二、待确认（记录，不擅自改）

| # | 轴 | 事项 | 为什么先不改 |
| --- | --- | --- | --- |
| A | 标准 | `heroAsCard` 读的是 `MileafColors.lerp` 的插值色，200ms 主题切换的末段 ΔL\* 穿过 20，hero 会在动画中途从卡片翻成满幅（外距 12→0、品牌行回 hero） | 两种形态结构不同，任何实现都只翻转一次；把翻转点提前/推后或平滑掉都需要「让形态本身参与动画」——Spec §11 明确不要 hero 进入动画，批 2 的边界也是「不改结构」。已在 `semantic.dart` 的 `heroAsCard` 上写明这是已知瞬态。若要真正消除，需单独一张票（形态过渡动画）。 |
| B | 规格 / 设计 | 浅色 `seriesSecondary` = `#0B62C4` 与 `reference` = `#5F6B78` 明度比只有 1.08，靠色相区分；深色下次系列比主色更暗（2.41），「次系列比主色轻」的方向反了 | 这是 AV06 唯一的视觉取舍，批 2 已标记「可能需要用户复核」。`accent` 50% 的两模式对比度只有 1.78 / 2.78，不满足 3:1，所以不能回退；替代方案（third hue）会引入第二强调色，违 §3.4。**需要用户在「保住 3:1」与「保住淡次系列」之间做决定。** |
| C | 标准 | `statistics_usage_page` 的热力格最强格按 `isDark` 选墨色（浅 `text` / 深 `textOnAccent`），不是 §3.3 决策树的直接查表 | 该格底是 `accent` 72% 的浅蓝，两种模式的「正确墨色」恰好是相反的 token；语义层没有「accent 填充上的墨色」这一项，新增它属扩 API。当前写法有注释说明，且对比度已被 `design_tokens_test` 的单条断言守住（浅 7.60 / 深 4.79）。 |

## 三、按轴保留的原文结论

### 标准轴

- 硬违规 0：`lib/` 内除 `tokens.dart`／`semantic.dart` 外零 `Color(0x...)`；无裸字号/裸圆角视觉决策；未碰 `MileafServer/`、`teslamate/`；未推送。
- 通过项：`accentStrong` 进了 `lerp` 与 `copyWith`（有测试）；形态判据只写在 `heroAsCard` 一处；批 1/批 2 改写的既有断言都写明了「旧断言编码了哪个被推翻的决定」，不是把期望值改成实测值；图册自述「不是真机/真实站点证据」。
- 判断项（保留）：`mileafHeroPadding` 的卡片分支是 16/20 固定值、`lib/` 零调用（仅设计画廊渲染用），与「各调用点自定纵向」不完全一致 → 已补文档注释说明它是画廊默认盒，不是页面契约；`accentFocus`／`accentPressed` 仍是零调用的重复表达（批 1 遗留，删它会改 `MileafColors` 的 API 面，留作后续）。

### 规格轴

- 缺失/半成品 6 条：第 1–4、6 已修（见上表），第 5 条由本文件补齐。
- 蔓延 4 条：`seriesSecondary` 改值（已按 D5.1 追认）、删 `isDark` getter（死代码，零调用）、拆 `pressOverlay` primitive（取值不变）、补 `heroLight`／`accentSoftLight` 两个 primitive 命名（Spec §2.2 已补登记）。四者都在批 1/批 2 的偏离清单里有记录，属「实施时发现的规格缺口」，不是悄悄扩范围。
- 与规格不符 3 条：`button` 三 kind 共用高亮（已按 kind 分流）、次系列与参照的色相距离（待确认 B）、ADR 0003 的默认深色（已加行内修订）。
- 覆盖广度（保留为残余）：7 处 hero 只有概览与充电详情有几何断言，320 宽只测概览；「当前点」只有尺寸断言，没有两模式下的对比度断言。这两条已写进 Spec §13 的 `[~]` 标记与批 3 记录的残余风险。

## 四、修复后的验证

```sh
./tool/flutterw analyze --no-pub            # No issues found! (12.9s)
./tool/flutterw dart format --output=none --set-exit-if-changed lib test
                                            # Formatted 159 files (0 changed)
./tool/flutterw test --no-pub               # +427 ~23: All tests passed!
```

（批 2 结束时是 423 通过；本轮 +4：两条「强调色分层」widget 测试、一条「深浅两层强调色合并」单测、一条「冷启动首帧」widget 测试。）

渲染图册按修复后的源码重出（高亮色只在按压时出现，图册像素不变，但源码指纹已更新，见 [appearance-v2-renders/README.md](appearance-v2-renders/README.md)）。
