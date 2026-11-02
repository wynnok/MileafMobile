# 外观 v2 实施与验证

2026-11-02；基线 `7ee84f0`（`main` 与 `codex/mileaf-v1` 同一提交）。依据 [ADR 0006](../adr/0006-appearance-and-accent.md)、[Spec](../specs/appearance-v2.md)、[Ticket 计划](../specs/appearance-v2-tickets.md)。本文件按批追加；下一批开工前先读最新一节，不重复推断已完成的事实。

## 批 1 记录（2026-11-02）

### 范围

AV01、AV04、AV05：色板基座（tokens / semantic / theme）、默认外观与设置、组件层「文字类 accent」归类。**不改版面**：hero 形态、概览头部归属、间距档位、字号阶梯、圆角与动效全部未动。

改动文件（13 个）：

- `lib/src/design/tokens.dart`：`MileafPalette` 整块替换为 azure/slate/paper/mist/graphite/steel/amber/red；删除 `jade*`、`stone*`、`sand*`、`clay*`、`ink*`、`heroOnLight`；线条/叠加常量改由中性色派生；`MileafElevation.sheetLight` 改中性 `0x1A0E1319 0/12/40`；新增 `MileafSpace.cardInset = 12`、`MileafSpace.cardPad = 16`。
- `lib/src/design/semantic.dart`：`MileafColors.dark()` / `.light()` 全量改值，新增 `accentStrong`，`copyWith` / `lerp` 补齐（主题 200ms 过渡里文字色也参与插值）。
- `lib/src/design/theme.dart`：`ColorScheme.primary → accent`、`onPrimary → textOnAccent`、`primaryContainer → accentSoft`；`floatingLabelStyle`、`snackBar.actionTextColor`、`textButtonTheme`、`chipTheme.secondaryLabelStyle`、`filledButtonTheme` 走 `accentStrong`；`progressIndicator`、`slider`、`switch.track`、`checkbox.fill`、`radio`、`textSelection` 保持 `accent`。
- `lib/src/appearance.dart`：`_mode` 初值与 `restore()` 回退均为 `system`；枚举声明顺序改为 跟随系统 / 浅色 / 深色。
- `lib/src/appearance_sheet.dart`：文案改「默认跟随系统。切换后立即生效，并保存在本机。」；选中行文字 → `accentStrong`，勾选图标仍 `accent`；行序即枚举序。
- `lib/main.dart`：注释说明主题由 `themeMode` 决定、`system` 由平台亮度解析（无逻辑改动）。
- `lib/src/appearance.dart` 另删除死代码 `isDark` getter：它在 `system` 下恒为 `false`，`lib/`、`test/` 内均无调用方，留着只会诱导把「系统深色」判成浅色。
- `lib/src/design/components/chip.dart`、`nav_bar.dart`、`button.dart`、`workspace_page.dart`、`connection_page.dart`：见下文「偏离 Spec 的地方」。
- `test/design_tokens_test.dart`、`test/appearance_shell_test.dart`：见下文「有意改动的既有测试」。

### 命令与实测数字

```sh
./tool/flutterw analyze --no-pub
# No issues found! (12.5s)

./tool/flutterw test --no-pub
# 00:53 +403 ~23: All tests passed!   （403 通过、23 默认跳过）

./tool/flutterw dart format --output=none --set-exit-if-changed lib test
# Formatted 159 files (48 changed) in 0.68 seconds.  → exit 1
```

格式化这一项**未达到 0 changed**，但不是本批引入的：在干净 HEAD（`git worktree add /tmp/x HEAD`）上用同一工具链执行同一命令，同样是 `159 files (48 changed)`，且两次的 48 个文件**集合完全相同**（本批未让任何文件新进入该集合）。原因是仓库现存代码用的是 dart_style 旧风格（trailing-comma 强制换行的短风格），而项目固定的 `.tooling/flutter`（Dart 3.13.5，`package_config` 语言版本 3.13）默认启用 tall style：即使 `--language-version=3.6`、`--trailing-commas=preserve`、不同 `--page-width` 也复现不出 HEAD 的排版。修它需要一次覆盖 48 个文件的全仓机械格式化，属独立提交，不在本批范围；本批新增代码按仓库现有风格书写，并自查过新增行不超过 80 列（CJK 字符串除外）。

### 有意改动的既有测试

| 位置 | 旧断言 | 为什么必须改（旧断言编码了哪个被推翻的决定） |
| --- | --- | --- |
| `design_tokens_test.dart` 对比度表 | 深 18.16 / 6.59 / 5.07 / 12.03 / 10.06 / 9.17 / 7.59 / 11.64，浅 16.00 / 4.94 / 4.59 / 5.64 / 5.17 / 6.54 / 5.10 / 6.10 | 这些数字是 ADR 0003 的「玉绿 + 暖米 + 暖砂」色板实测值。ADR 0006 D2/D3/D5 已把强调色换成电光蓝、中性底去绿去暖、参照改石墨，数值整表失效。按 Spec §3 重算：深 17.87 / 7.87 / 5.59 / 8.05（accent 与 accentStrong）/ 6.80 / 10.77 / 7.75 / 8.05（textOnAccent 在 accent 上）；浅 17.10 / 5.38 / 4.65 / 3.25 / 5.41 / 5.90（textOnAccent 在 accentStrong 上）/ 4.99 / 4.60 / 4.90。`_expectContrast` 增加 `minimum` 参数：文字 4.5、图形 3.0，这样浅色 accent 的 3.25 是按 §1 R3 通过的图形阈值，而不是被 4.5 蒙过。 |
| `design_tokens_test.dart` 浅色 hero 组 | `heroMuted` 落在 8.4–9.7 区间、`heroFaint ≥ 4.5`，且用 `MileafPalette.jade900` 当深色 hero 底 | 旧区间只是「玉绿 hero + `#9FB9AA`」这一组合的数值范围；ADR 0006 D3 把 hero 文本换成 mist 系（`#F2F4F7` / `#A7B4C2` / `#8A96A4`），区间不再有含义。改为逐项对比度（浅 hero 17.90 / 9.34 / 6.55 / 8.06，深 hero 18.10 / 9.45 / 6.63），并改用语义 token 当底色。「浅色仍保留深色 hero 锚点」这个决定本身未变。 |
| `design_tokens_test.dart` primitive 硬断言 | `dark.hero == jade900`、`light.hero == jade800`、`dark.canvas == canvasDark`、`light.canvas == stone50`、`light.accent == jade500`、`light.accentHero == jade300`、`dark.accent == jade300` | 断言绑定的是 Spec §2.2 明令删除的 primitive 家族（jade/stone/ink/sand/clay）。改为 azure/slate/paper 系，并补 `light.accentStrong == azure600`、`light.surface == paper0`、`dark.accentStrong == dark.accent`（深色合并两层是 §1 R3 的有意设计）。 |
| 同上（新增） | — | 新增明度阶断言：浅 canvas→surface ≥3、浅 canvas→hero ≥80、深 canvas→surface ≥3、深 canvas→hero ≤2（Spec §3.3，实测 3.49 / 93.58 / 4.09 / 0.61）。新增 hero 卡片几何与中性浅色阴影断言（`cardInset 12`、`cardPad 16`、`sheetLight = 10% 石墨 0/12/40`），让这两项在批 2 消费之前就有守卫。 |
| 同上（新增） | — | 新增「线条与叠加层透明度」（line 9/14、10/16；nav 88/92；scrim 50/35；skeleton 7/6；accentSoft 16%；pressOverlay 4/6；focusRing 60%）与「accentStrong 参与 copyWith 与主题插值」两组断言：前者守住 §3 的 alpha（对比度算不出错项），后者守住 §13「主题切换有 200ms 颜色过渡」。 |
| 同上（改写） | `sheetLight` 的颜色断言复用 `MileafPalette.lineLight` | 两者只是恰好同为 `0x1A0E1319`，语义无关；任一侧微调都会误报。改为直接断言 Spec §5.2 的字面值。 |
| 同上（改名） | 测试名「主题挂载语义与字号扩展，且默认深色底」 | 名字里的「默认深色底」是被 ADR 0006 D1 推翻的旧决定，改为「两种亮度都挂 canvas 底」。 |
| `appearance_shell_test.dart` 「默认深色，保存后恢复」 | `mode == dark`、`themeMode == ThemeMode.dark` | 旧断言编码「深色是产品默认」（ADR 0003 / visual-system-a §9.8），被 ADR 0006 D1 推翻：首启无保存值时为跟随系统。 |
| `appearance_shell_test.dart` 「未知值保留深色，写入失败回滚」 | 读不到/非法值回退 `dark` | 同一条被推翻的决定；`restore()` 现在保留 `system`，写入失败仍回滚到上一个值。 |
| `appearance_shell_test.dart` 「冷启动默认深色…」 | `themeMode == dark`、首帧 `Brightness.dark` | 同上；改为 `ThemeMode.system`，首帧亮度等于平台亮度（测试平台默认浅色，因此断言浅色，这同时验证了「不先深后浅」）。测试改为先 `restore()` 再 `pumpWidget`，与 `main()` 的真实启动顺序一致。 |
| `appearance_shell_test.dart` 「设置中的外观切换生效并持久化」 | `expect(find.text('深色'), findsOneWidget)`（设置页 meta 显示当前值＝深色） | 旧断言假设默认值是深色。默认改 `system` 后行内 meta 为「跟随系统」。同一条测试补齐 sheet 内三项顺序（跟随系统 / 浅色 / 深色，用 y 坐标比较）、说明文案、切换后 meta 变「浅色」。跟随系统时文本在设置页与 sheet 各出现一次，故用 `find.descendant(of: find.byType(BottomSheet))` 限定。 |
| 同上（新增两条） | — | ①「system 下平台亮度切换后 `Theme.brightness` 跟随」（深→浅→深，且不写本机偏好）；②「已保存的偏好优先于系统亮度」。对应 Spec §13 第 1 条与 Ticket AV04 验收。 |

没有改动 `design_components_test.dart`、`a_overview_test.dart`、`design_gallery_render_test.dart`：其中与颜色相关的断言（hero 底色、状态栏图标、深色 error 文案）在本批后仍然成立。

### 偏离 Spec 的地方

色值一律照 Spec §3 抄录，未改任何 hex；以下是票面未写、但为满足批 1 出口条件或避免断链而做的解释性决定：

1. **两个 primitive 名 Spec §2.2 没有登记**：一是浅色 hero `#070B11`（§2.2 的 slate 档位只覆盖深色，`slate1000 = #06090E` 是深色 hero），二是浅色 `accentSoft #DCEBFD`（§3.2 给了值，§2.2 的 azure 档位没给名字）。新增 `MileafPalette.heroLight = Color(0xFF070B11)` 与 `MileafPalette.accentSoftLight = Color(0xFFDCEBFD)`，两个值都严格取自 §3.2；未复用 `slate1000` 以免同一 primitive 承载两个色值。旧 `heroOnLight` 是语义名字，已按 §2.2 删除。批 3（AV08）应把这两行补进 Spec §2.2 的命名表，否则下一批还会再命名一次。
2. **`accentPressed` 保留**：Spec §2.3 的改值/不变清单都没提它，但 `MileafColors` 仍暴露该字段（`lib/` 内零调用）。为不越出「只做三张票」的 API 面，保留字段并映射到最近档位（深 `azure300`、浅 `azure600`），`copyWith` / `lerp` 一并保留。若 AV08 决定清理，可整条删除。
3. **`pressOverlay` 拆成两个 primitive**：当前 getter 用 `isDark ? 硬编码 : text.withValues(alpha: .06)` 现场混色，与「叠加类常量由中性色派生」不一致。改为 `pressOverlayDark`（`#F2F4F7` 4%）与 `pressOverlayLight`（`#0E1319` 6%），取值与 Spec §3 一致，getter 返回值不变。
4. **`connection_page.dart` 的站点健康提示文字**：不在 Ticket AV05 的清单里，但它是正文文字用了 `accent`；不改就违反批 1 出口条件「浅色下无低于 4.5:1 的蓝字」与 Spec §3.3 决策树，改为 `accentStrong`。
5. **`chip.dart` 的 `onHero` 分支按 §7.1 补齐**：选中态描边 `accentHero`、文字 `heroText`、底 `heroText` 12%。原先这条分支用 `accent` 兼作文字与描边，浅色下落在深色 hero 上只有 ~4.6:1 以下的对比。全仓当前没有任何 `StatusChip` 传 `onHero: true`（参数是死分支），因此这一改动不改变任何现有页面的观感，只是把矩阵补齐。
6. **枚举声明顺序**改为 system / light / dark，使 `MileafAppearance.values` 直接就是设置项顺序（默认项置顶）。持久化按 `name` 读写，已保存 `light`/`dark` 的设备不受影响。

### 未完成 / 已知问题

- **hero 卡片形态与概览头部归属（AV02 / AV03）未做**，属批 2。本批新增的 `MileafSpace.cardInset`、`cardPad` 暂无消费方，仅由 `design_tokens_test` 守住。
- **图表与专项页颜色复核（AV06）未做**；`reference` 改石墨、系列次色仍是 `accent` 50%，需要在批 2 用渲染确认可读。
- **正式渲染（AV07）、文档同步（AV08）、双轴审查（AV09）未做**。色板图 `docs/product/appearance-v2-palette.png` 只是设计对照图，不是 Flutter 渲染。
- **全仓格式化基线是红的**（见上）。本批未引入新漂移，但 `--set-exit-if-changed` 仍会失败；建议在批 2 之前单独做一次机械格式化提交，避免和结构性改动混在一起。
- **按压高亮仍是 `accent` @12%，不是 `accentSoft`**：`button.dart`、`chip.dart`、`nav_bar.dart`、`appearance_sheet.dart`、`workspace_page.dart`、`metric.dart`、`icon_button.dart` 的 `InkWell.highlightColor`。§7.2「按压 高亮 `accentSoft`」、§7.4「未选 … `accentSoft`（InkWell）」、§3.4「不用 `accent` 做整块背景或大面积填充」都指向 `accentSoft`。本批按 AV05 的调用点清单只改文字与实心底，未动这 7 处（深浅两模式的观感差别很小，但确实是第三种「accent 当填充」的用法）；**归入批 2 的 AV06 或单列一张票**，一次改完，避免半改造成不一致。
- `accentFocus`（azure300 60%）在 `lib/` 内零调用，`focusRing` 另算 `accent` 60%；`accentPressed` 同样零调用。两者都是历史遗留的重复表达，本批按 §2.3「保持语义不变」只改值不改结构，留作 AV08 清理候选。
- Spec §3.3 的「已知文字类调用点」把 `workspace_page.dart:408` 也列成文字；实际那是选中车辆的勾选图标（§7.4 规则是图形 → `accent`）。代码是对的，是 Spec 的引用行号过时，属 AV08 文档同步。
- 浅色现在是绝大多数未设置用户的首屏（默认跟随系统），而浅色的桌面观感要等 AV07 渲染才有证据；当前只有对比度与布局回归背书。

### 下一批入口

批 2 = AV02 + AV03 + AV06，顺序建议 AV02 → AV03 → AV06：

- hero 形态判据：`ΔL*(hero, canvas) > 20 → 卡片`。本批已保证深色 0.61、浅色 93.58，判据在当前取值下分别是满幅与卡片。
- 新增 `MileafLayout.heroInset(context)`：卡片 → `cardPad(16)`、满幅 → `pageInset`；7 处调用点替换，不在页面里各自判断形态。
- 卡片形态下 `MileafHero` 不再声明 `SystemUiOverlayStyle.light`；`overview_page` 的 `_topInset()` 只在满幅返回状态栏高度。
- 已知会被挡住的既有测试：`a_overview_test.dart` 的「浅色下『行笺』字标颜色 == heroText」（浅色 top bar 回纸面后应为 `text`）、`design_components_test.dart` 的浅色 hero 断言（仍然成立，但要补「卡片形态不覆盖系统栏」）；均属 AV03/AV02。
- 本批自审（两轴，基线 `0b6ae57`）已修：补 `accentStrong` 插值/`copyWith` 与透明度断言、`sheetLight` 断言改为 Spec 字面值、删除误导性的 `AppearanceController.isDark`、两处 primitive 命名补进偏离清单、测试改名去掉「默认深色底」。带进下一批的：按压高亮 7 处（见上）、`accentFocus`/`accentPressed` 重复表达、§3.3 的过时行号。

## 批 2 记录（2026-11-02）

### 范围

AV02、AV03、AV06：hero 卡片形态、概览头部归属、图表颜色复核。这是外观 v2 里**唯一的**结构性改动批次。未改版面内容顺序与数量、未改字号/间距档位/圆角体系、未改图表几何、未引入新图表类型、未改交互与 `Semantics`。色值一律取自既有 `MileafPalette`（**没有新增 hex**）。

改动文件（12 个 lib + 4 个 test）：

- `lib/src/design/semantic.dart`：新增私有 `_lStar()` 与 `bool get heroAsCard`（判据见下）；`seriesSecondary` 由 `accent 50%` 改为 `azure600`（AV06，理由与实测见「偏离」第 6 条）。
- `lib/src/design/layout.dart`：新增 `MileafLayout.heroInset(context)`：卡片 → `cardPad(16)`，满幅 → `pageInset(20/24)`。
- `lib/src/design/components/hero.dart`：形态由 `MileafColors.heroAsCard` 推导，构造参数未变（调用方无从指定形态）。卡片：左右 `cardInset(12)`、圆角 `lg(20)`、无描边无阴影、光晕按卡片尺寸推导、**不声明** `AnnotatedRegion<SystemUiOverlayStyle>`、不加状态栏 inset。满幅：行为与批 1 完全一致（光晕 + `SystemUiOverlayStyle.light` + `heroTop`）。`mileafHeroPadding()` 同样按形态返回（卡片 16/20/16/20，满幅原样）。
- `lib/src/overview_page.dart`：`_topInset()` 在卡片形态返回 0；卡片形态把 `topBar` 挪到 `ListView` 第一项（纸面），hero 紧随其后；两处 hero 横向 `pageInset` → `heroInset`。
- `lib/src/workspace_page.dart`：概览 `topBar(onHero: !context.colors.heroAsCard)`。通知条底色本就是 `surface`，无需改动。
- `charging_page.dart`、`charging_detail.dart`、`statistics_insights_page.dart`、`statistics_parking_page.dart`：横向 `pageInset` → `heroInset`。
- `charts.dart`：唯一的水平网格线（零基线）改为纸面 `line` / hero 内 `heroText` 12%（Spec §8；原先是 `text`/`heroText` 18%）。
- `category_bars.dart`：`accent / accent 50% / textFaint` 改为 `seriesPrimary / seriesSecondary / seriesNeutral`，与 `composition_bar` 同一口径（数值变化仅来自 AV06 的次系列决定）。
- `statistics_usage_page.dart`：热力格 9px 日期在最强格上的墨色改为深墨（见「偏离」第 6 条）。

### 形态判据

```
Δ L*(hero, canvas) > 20  →  卡片      // 实测：浅色 93.58
Δ L*(hero, canvas) ≤ 20  →  满幅      // 实测：深色 0.61
```

判据只写在 `MileafColors.heroAsCard` 一处，计算用语义层的私有 `_lStar()`（`computeLuminance` → CIELAB L\*）。`design_tokens_test.dart` 除了断言两种模式的现状，还用 `#2C2C2C`（Δ15）与 `#474747`（Δ27）夹住 20 这个阈值——阈值本身被守住，而不是只守住今天恰好成立的取值。

### 7 处 hero 调用点

| # | 位置 | 形态相关改动 |
| --- | --- | --- |
| 1 | `overview_page.dart:636/638`（车况 hero） | 横向 `heroInset`；`_topInset()` 卡片下归零 |
| 2 | `overview_page.dart:715/717`（hero 骨架） | 同上 |
| 3 | `overview_page.dart:762`（hero 缺失/错误） | 无横向 `pageInset` 可替换（`StateView` 自带固定 `s20`），见「偏离」第 2 条 |
| 4 | `charging_page.dart:856`（已知充电费用） | 横向 `heroInset` |
| 5 | `charging_detail.dart:400/402`（电量区间弧） | 横向 `heroInset` |
| 6 | `statistics_insights_page.dart:789/791`（里程走势） | 横向 `heroInset` |
| 7 | `statistics_parking_page.dart:364/366`（SOC 变化） | 横向 `heroInset` |

7 处全部覆盖：6 处有横向 `pageInset` 的调用点已替换，第 3 处没有横向 `pageInset`（空态由 `StateView` 自带留白），所以全仓 `hero` 内已无 `MileafLayout.pageInset` 残留。形态判断只出现在 `semantic.dart`（`heroAsCard`）与消费它的 `heroInset` / `MileafHero` / `overview_page._topInset` / `workspace_page` 的 `onHero`，页面里没有第二份 ΔL\* 计算。

### 命令与实测数字

```sh
./tool/flutterw analyze --no-pub
# No issues found! (12.9s)

./tool/flutterw test --no-pub
# 00:47 +423 ~23: All tests passed!   （423 通过、23 默认跳过；批 1 是 403，本批净增 20 条）

./tool/flutterw dart format --output=none --set-exit-if-changed lib test
# 批 2 本体提交后紧接着一次机械格式化提交（2cb51d8）：
# Formatted 159 files (0 changed) in 0.77 seconds.  → exit 0
```

几何核对（`a_overview_test.dart` 的矩阵，2 模式 × 320/360/390 × 100%/200% 共 12 条）：卡片左右外距 12、内容宽 264/304/334（= 宽 − 12×2 − 16×2）；满幅内容宽 280/320/342（= 宽 − pageInset×2），与 Spec §6.5 逐项一致，全部无横向溢出。

### 有意改动的既有测试

| 位置 | 旧断言 | 为什么必须改（旧断言编码了哪个被推翻的决定） |
| --- | --- | --- |
| `a_overview_test.dart:183-190` | 浅色下「行笺」字标颜色 == `heroText` | 旧断言编码「概览 top bar 永远在 hero 内」。ADR 0006 D4 / Spec §6.4 推翻它：浅色 hero 成卡片后品牌行回到纸面，字标必须用纸面正文色 `text`；深色仍在 hero 内，因此改为按模式取值（深 `heroText` / 浅 `text`）。 |
| `a_charging_detail_test.dart` 「A 充电详情电池弧 hero 全出血…」 | `hero.left == 0`、`hero.right == 360`、内容 `left ≥ 20` | 同名旧断言编码「hero 永远全出血」。本批后用 `getRect(MileafHero)` 量到的是**外框**（卡片形态下它仍然整行宽），旧断言会假绿，所以改为量可见卡片：左右 `12 / 348`、内容 `left = 28`（12 + 16），并改名去掉「全出血」。 |
| `design_components_test.dart:40-160` | 深色锚点光晕 + 浅色页仍用深色 hero | **未改**，仍然成立。按 Ticket 要求补了 4 条卡片形态断言（见下）。 |

新增断言：

- `design_tokens_test.dart`：hero 形态判据与 20 L\* 阈值上下界；图表主系列/次系列/参照/中性序列在 canvas 与 surface 上 ≥3:1、轴标签 ≥4.5:1、主次系列间 ≥1.4:1（不合并）、hero 内 `accentHero`/`heroFaint` 达标；热力格最强格的 9px 标签 ≥4.5:1。
- `design_components_test.dart`：浅色卡片量出左右各 12、`borderRadius == 20`、`elevation == 0`、hero 子树内**不存在** `AnnotatedRegion<SystemUiOverlayStyle>`；深色满幅（卡片 rect == hero rect）且声明 `statusBarIconBrightness == light`；320 宽 200% 不溢出。
- `a_overview_test.dart`：上面那张 12 条的矩阵（形态 + 品牌行归属 + 内容宽）；「浅色 → 深色 → 浅色不残留双倍 inset」（两次浅色的卡片 rect 完全相同、切换回浅色仍紧贴品牌行区块）。

### 偏离 Spec 的地方

没有新色值，也没有改字号/间距档位/圆角体系。以下是与 Spec 字面表述不完全一致的几何或取值选择：

1. **卡片只加左右 12，不加纵向 12**（§6.3 写「上下各 12」）。组件加纵向外边距会把概览的「品牌行 → 卡片」变成 24（品牌行自身已有 12 下内边距），也会挪动其它页既有的 8/16/28 纵向节奏。现在：概览的卡片距品牌行正好 12（来自 `MileafTopBar` 自身的下内边距），其余页 hero 与相邻区块的纵向间距保持页面原有档位。
2. **缺失/错误态 hero 的内容左右是 32，不是 28**：`StateView` 的横向内边距是固定的 `s20`（12 + 20），它是共享组件、非 hero 页也在用，本批没有为 4px 改它的 API。
3. **卡片内纵向 padding 沿用各调用点原值**（概览 `s4`/`heroBottom 18`，充电费用与两个统计 hero 本来就是 `s20`/`s20`）。§6.3 的「纵向 20」只对后四处字面成立；概览保持原值以免改动 hero 内部排版（AV02 明确不做）。
4. **光晕用盒内分数坐标实现**：卡片形态把 §6.3 的圆心 `(w×1.02, −h×0.15)` 写成 `Alignment(1.04, -1.3)`、半径 `0.95`（盒内短边比例），这样宽度和「内容驱动、构建期不可知」的高度都由盒子自己解析，峰值仍是 18%。满幅形态按「保持现有行为」保留原固定 420 圆盘（与 §6.2 的公式本来就不完全一致，属既有实现）。
5. **§9 的「≥560 时卡片在内容限宽 560 内」未施加**：hero 与页面其它块一样直接铺满，没有引入 `MileafContent`（会把 hero 变成另一个几何体系，超出 AV02 范围）。
6. **AV06 改的是「用哪个既有 token」，不是新色**，共四处：
   - `seriesSecondary`：`accent 50%` 合成为**浅 1.78 / 深 2.78**，两模式都不到 3:1，也就无法满足 Ticket 的「主/次系列在各自底色 ≥3:1」。改为 `azure600`：#0B62C4 对白卡 5.90、对深色 surface 3.07，与主色相差 1.66 / 2.41。代价是浅色下 DC 段从「淡蓝」变成「深蓝」（本会话临时渲染 `a_charging_method` 已确认可分辨；未归档，正式图册归 AV07），且它与 `reference` 石墨在浅色下明度接近（1.07），靠色相区分——**这是本轮唯一可能需要你复核的视觉取舍**；若要保留「50%」的字面，则 Ticket 的 3:1 验收项必须改写。
   - 图表零基线：`text`/`heroText` 18% → 纸面 `line`、hero 内 `heroText` 12%（§8 的字面值）。
   - 热力格 9px 日期：最强格（`accent` 72%）上的白字只有浅 2.45 / 深 4.11，改为深墨（浅 `text` 7.60、深 `textOnAccent` 4.79）。
   - `category_bars` 由内联 `accent`/50%/`textFaint` 改为 series token（取值只随上一项变化）。

### 未完成 / 已知问题

1. **全仓格式化基线已收口**：批 2 拆成两个本地提交——`656de86` 是本批本体（按仓库现存风格书写，新增行自查 ≤80 列），`2cb51d8` 是紧随的**纯机械格式化**（`dart format lib test`，47 文件重排）。逐文件比对「去掉空白与逗号后的字符流」，除 `overview_page.dart` 里为满足 `curly_braces_in_flow_control_structures` 补的两只花括号（行为不变）外完全相同。最终 `--set-exit-if-changed` = 0 changed、analyze 0 issue、test 423/23。这落实了批 1 建议的「把机械格式化和结构性改动分开」。本记录引用的行号均为这两个提交之后的树。
2. `test/owner_statistics_render_test.dart`（opt-in 渲染，默认 skip）仍按已被替换掉的五个 ChoiceChip（「节奏/能耗/补能/长期」）点击，**既有问题、非本批引入**；AV07 出图册前必须先修，否则拿不到统计专题的正式渲染。
3. 按压高亮仍是 `accent` @12%（批 1 遗留 7 处），本批未动：它属 AV05/AV06 的交界，但与图表读数无关，建议在 AV08 一次改完。
4. `accentFocus`、`accentPressed` 仍是零调用的重复表达（批 1 遗留）。
5. 卡片形态没有做「进入动画」（§11 明确不要），也没有阴影/描边——本会话临时渲染过 `overview-normal-light-{100,200}`，确认卡片是纯底色 + 光晕、200% 下内容纵向堆叠且无横向溢出（未归档）。
6. 真机、真实站点/地图、性能、双端隔离构建仍是独立外部 gate，本批不改变其状态。

### 下一批入口

批 3 = AV07 + AV08 + AV09：

- **AV07 渲染图册**：先修 `owner_statistics_render_test.dart` 的过时 ChoiceChip 点击（见上「未完成」第 2 条），再按 320/360/390 × 浅/深 × 100%/200% 重出四主 Tab + 两类详情。量图时注意：`getRect(MileafHero)` 在卡片形态下是**外框**（整行宽），要量里面的 `Material`。
- **AV08 文档同步**：`visual-system-a.md` §4 hero 形态、§9.8 默认外观、§14 第 1 条；`appearance-v2.md` Spec 需改三处——§8 的「系列次色 `accent` 50%」改成 `azure600` 并补实测、§6.3 的「上下各 12」与「纵向 20」按本记录第 1/3 条对齐、§2.2 补 `heroLight`/`accentSoftLight`（批 1 遗留）。
- **AV09 双轴审查**：重点看 ①形态判据是否被任何页面绕过 ②卡片纵向节奏是否需要统一成 12 ③`seriesSecondary` 这一处 AV06 取舍要不要保留。
