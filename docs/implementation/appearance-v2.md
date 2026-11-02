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
