# 外观 v2：实施 Ticket 计划

- 日期：2026-11-02
- 状态：待确认
- 依据：[Spec 外观 v2](appearance-v2.md)、[ADR 0006](../adr/0006-appearance-and-accent.md)（已 accepted）
- 本地 ID：`AV01–AV09`。确认后按 `docs/agents/issue-tracker.md` 映射 GitHub；**本轮不直接创建或关闭 issue**。
- 实施边界：不改接口与数据语义、不改 `MileafServer/`/`teslamate/`、不改地图 provider 与原生依赖、不动版面结构与字号阶梯。真机、真实站点/地图、性能、双端隔离构建仍是独立外部 gate。

## 全局完成定义（DoD）

每张票都要满足：

- `tool/flutterw analyze --no-pub` 通过；`tool/flutterw dart format --output=none --set-exit-if-changed lib test` 无改动。
- `tool/flutterw test --no-pub` 通过；新增/更新的断言在同一 seam（App + 可控 HTTP + 合成 fixture）内。
- `lib/` 内除 `design/tokens.dart`、`design/semantic.dart` 外零 `Color(0x...)`；页面无裸字号/裸圆角作为视觉决策。
- 360×800 × 浅/深 × 100/200% 无横向溢出；主数、单位、操作可见。
- 空/加载/错误/缺失/过期/进行中仍有实际渲染。
- 不把浏览器原型图、色板图或合成数据当作真机/真实站点验收。

## 依赖图

```text
AV01 ─┬── AV02 ── AV03 ─┐
      ├── AV04           ├── AV07 ── AV08 ── AV09
      ├── AV05 ──────────┤
      └── AV06 ──────────┘
```

可并行：AV02 / AV04 / AV05 / AV06（都只依赖 AV01）。AV03 依赖 AV02；AV07 依赖 AV02+AV03+AV05+AV06；AV08、AV09 串行在最后。

**唯一结构性改动**是 AV02+AV03（hero 卡片形态与概览头部归属），其余都是颜色映射与断言更新。除 AV02/AV03 外每张票都可独立回滚。

## 三批实施切分（2026-11-02）

单会话上下文不足以一次完成 AV01–AV09，按"颜色事实 → 结构 → 证据与收口"切成三批，**串行**执行，每批结束时本地提交一次、并写交接记录。

| 批次 | 票 | 主题 | 出口条件 | 提交信息 |
| --- | --- | --- | --- | --- |
| 批 1 | AV01、AV04、AV05 | 颜色与外观基座，**不改版面** | analyze/format/test 全绿；首启为跟随系统；浅色下无低于 4.5:1 的蓝字；深浅 hero 形态与版面均未变 | `外观 v2 批 1：电光蓝色板、两层强调色、默认跟随系统` |
| 批 2 | AV02、AV03、AV06 | hero 卡片、概览头部、图表复核 | 浅色 7 处 hero 均为卡片、深色仍满幅；浅色概览品牌行在纸面；图表两模式可读；全测试绿 | `外观 v2 批 2：浅色 hero 卡片、概览头部归属、图表色复核` |
| 批 3 | AV07、AV08、AV09 | 渲染图册、文档同步、双轴审查 | 图册归档；仓库无与新决策矛盾的表述；`code-review` 明确问题 0；最终提交 | `外观 v2 批 3：渲染图册、文档同步与双轴审查` |

### 交接约定

每批结束在 `docs/implementation/appearance-v2.md` 追加一节（文件不存在则创建）：

```
## 批 N 记录（YYYY-MM-DD）
- 范围：AVxx、AVyy
- 命令与结果：analyze / format / test 的实测数字
- 有意改动的既有测试：文件:行 → 新断言的理由
- 未完成 / 已知问题：
- 下一批入口：
```

下一批开工前先读这一节，不要重复推断已完成的事实。

## 已知会被现有测试挡住的地方

| 测试 | 现有断言 | 为什么会红 | 归属 |
| --- | --- | --- | --- |
| [design_tokens_test.dart:47-70](../../test/design_tokens_test.dart#L47-L70) | 旧对比度数值 | 色板全量替换 | AV01 |
| [design_tokens_test.dart:72-83](../../test/design_tokens_test.dart#L72-L83) | `heroMuted` 落在 8.4–9.7 区间 | hero 文本色改为 mist 系 | AV01 |
| [design_tokens_test.dart:177-187](../../test/design_tokens_test.dart#L177-L187) | `light.hero == jade800`、`light.accent == jade500` | primitive 改名 | AV01 |
| [appearance_shell_test.dart:96-141](../../test/appearance_shell_test.dart#L96-L141) | 默认 `dark`、未知值回退 `dark` | 默认改 `system` | AV04 |
| [a_overview_test.dart:164-195](../../test/a_overview_test.dart#L164-L195) | 浅色下 `行笺` 字标颜色 == `heroText` | 浅色 top bar 回纸面，字标改 `text` | AV03 |
| [design_components_test.dart:75-85](../../test/design_components_test.dart#L75-L85) | 浅色 hero 仍深色 | **仍然成立**，但要补一条"卡片形态不声明 `SystemUiOverlayStyle.light`" | AV02 |

改这些断言时必须写清"旧断言编码了哪个被推翻的决定"，而不是把期望值改成实测值蒙过去。

---

## AV01 · 色板基座：tokens / semantic / theme

**目标**：把 ADR 0006 的色板落成唯一事实来源，其余票只消费。

**改动**
- `lib/src/design/tokens.dart`
  - `MileafPalette` 整块替换为 Spec §2.2 的 `azure / slate / paper / mist / graphite / steel / amber / red`；删除 `jade*`、`stone*`、`sand*`、`clay*`、`ink*`、`heroOnLight`。
  - 线条/叠加类常量改由中性色派生：`lineDark #F2F4F7 9%`、`lineStrongDark 14%`、`lineLight #0E1319 10%`、`lineStrongLight 16%`、`navDark #0A0B0D 88%`、`navLight #FFFFFF 92%`、`scrimLight #0E1319 35%`、`skeleton*`、`pressOverlay`、`accentSoftDark #64A8FF 16%`、`accentSoftLight #DCEBFD`、`accentFocus`。
  - `MileafElevation.sheetLight` 改 `Color(0x1A0E1319) 0/12/40`；`MileafSpace` 新增 `cardInset = 12`、`cardPad = 16`。
- `lib/src/design/semantic.dart`
  - `MileafColors.dark()` / `.light()` 全量改值；新增字段 `accentStrong`；`copyWith` 与 `lerp` 补齐。
  - `seriesSecondary` 仍为 `accent` 50%；`focusRing` 仍为 `accent` 60%。
- `lib/src/design/theme.dart`
  - `ColorScheme`：`primary → accent`、`onPrimary → textOnAccent`、`primaryContainer → accentSoft`、`secondary/tertiary → reference`。
  - 文字类映射改 `accentStrong`：`floatingLabelStyle`、`snackBar.actionTextColor`、`textButtonTheme.foregroundColor`、`chipTheme.secondaryLabelStyle`。
  - 图形类保持 `accent`：`progressIndicatorTheme`、`sliderTheme`、`switchTheme.trackColor`、`checkboxTheme.fillColor`、`radioTheme`、`textSelection`。
- `test/design_tokens_test.dart`：§2.4 对比度表按新值重算（浅 17.10/5.38/4.65/3.25/5.41/4.99/4.60/4.90；深 17.87/7.87/5.59/8.05/6.80/10.77/7.75），`浅色 hero` 与 `light.accent`/`dark.accent` 硬断言改写，新增明度阶断言（浅 canvas→surface ≥3、浅 canvas→hero ≥80、深 canvas→surface ≥3、深 canvas→hero ≤2）。

**验收**
- 对比度与明度阶测试全绿，且文本项 ≥4.5、图形项 ≥3.0。
- `MileafColors.dark()/light()` 的 25 个字段与 Spec §3 表逐项一致（测试断言关键项）。
- 主题切换 200ms 内 `accentStrong` 参与插值（widget 测试读两帧中间值不为首尾原色）。
- 除上述两个文件外没有新文件引用 `MileafPalette`。

**不做**：不改 hero 组件、不改任何页面、不改默认外观。

---

## AV02 · hero 卡片形态

**目标**：让 hero 在浅色成为"被设计过的物体"，深色保持"连续材质"。

**改动**
- `lib/src/design/components/hero.dart`
  - 形态由 `MileafColors` 推导：`Δ L*(hero, canvas) > 20 → card`；不再由调用方传 shape。
  - 卡片形态：外距 `cardInset(12)`、圆角 `lg(20)`、无描边无阴影、光晕半径按卡片宽度计算、**不声明 `SystemUiOverlayStyle`**。
  - 满幅形态：保持现有光晕与 `SystemUiOverlayStyle.light`。
- 新增 `MileafLayout.heroInset(context)`：卡片形态返回 `cardPad(16)`、满幅返回 `pageInset(20/24)`；7 处调用点把横向 `MileafLayout.pageInset(context)` 换成它，形态判断仍只发生在组件内。
- 7 处调用点：`overview_page.dart`（hero / 骨架 / 缺失 三处）、`charging_page.dart`、`charging_detail.dart`、`statistics_insights_page.dart`、`statistics_parking_page.dart`。

**验收**
- 浅色下 7 处 hero 均为卡片：左右各 12 外距、20 圆角、无阴影。
- 深色下 7 处 hero 仍满幅、仍覆盖浅色系统栏图标。
- 浅色卡片形态下 `AnnotatedRegion` 不再声明 light（widget 测试断言：浅色 hero 子树内不存在 `SystemUiOverlayStyle.light` 的覆盖，或断言其 `statusBarIconBrightness` 为 dark）。
- 320 宽与 200% 下卡片内容不溢出、不裁切。

**不做**：不改 hero 内部排版、字号、内容顺序。

---

## AV03 · 概览头部归属

**目标**：浅色下品牌行回到纸面，hero 不再吞掉状态栏。

**改动**
- `lib/src/overview_page.dart`：`topBar` 的 `onHero` 由形态决定（满幅 → true）；`_topInset()` 仅在满幅返回状态栏高度。
- `lib/src/workspace_page.dart`：`topBar(onHero: …)` 与形态一致；通知条底色随 `surface` 生效。

**验收**
- 浅色概览：状态栏区域是纸面、图标深色；品牌行在纸面；hero 卡片在其下 12。
- 深色概览：品牌行仍在 hero 内、图标浅色，与当前渲染一致。
- 切到浅色再切回深色，头部不残留空档或双倍 inset。
- 概览首屏的"车况 → 本月 → 主图起点"顺序不变。

**不做**：不改概览内容块顺序与数量。

---

## AV04 · 默认外观与设置

**目标**：首启跟随系统，设置项与文案一致。

**改动**
- `lib/src/appearance.dart`：`_mode` 初值 `system`；`restore()` 读不到/非法值保留 `system`；注释改为"跟随系统是默认"。
- `lib/src/appearance_sheet.dart`：文案「默认跟随系统。切换后立即生效，并保存在本机。」；枚举展示顺序改为 跟随系统 / 浅色 / 深色；选中项颜色走 `accentStrong`。
- `lib/main.dart`：注释更新（主题由 `themeMode` 决定，system 由平台亮度解析）。
- `test/appearance_shell_test.dart`：三条断言改写（默认 system、未知值回退 system、system 下 `platformBrightness` 切换后 `Theme.of(...).brightness` 跟随）。

**验收**
- 无保存值时 `themeMode == ThemeMode.system`；模拟平台深色 → 深色主题，浅色 → 浅色主题。
- 已保存 `light`/`dark` 的设备重启后仍按保存值，不被系统覆盖。
- 写入失败回滚到上一个值（沿用现有行为），不回退成 dark。
- 冷启动不出现"先深后浅"的闪色（测试用首帧断言 brightness）。

**不做**：不新增"自动亮度/定时切换"。

---

## AV05 · 组件层"文字类 accent"归类

**目标**：浅色下不再出现 3.25:1 的蓝色文字。

**改动**
- `chip.dart`：选中标签 → `accentStrong`；选中描边 → `accentStrong`。
- `nav_bar.dart`：选中标签 → `accentStrong`；18×2 指示条保持 `accent`。
- `button.dart`：primary 底 → `accentStrong`；ghost 文字 → `accentStrong`。
- `appearance_sheet.dart` / `workspace_page.dart` 的选中行文字与勾选图标 → `accentStrong` / `accent`。
- `theme.dart` 已在 AV01 覆盖。

**验收**
- 浅色下所有强调色文字（链接、chip 选中、导航标签、设置行）对比度 ≥4.5。
- 导航指示条、进度条、电池弧、图表仍用 `accent`。
- `test/design_components_test.dart` 状态矩阵（default/selected/disabled/focus）通过。

**不做**：不改组件尺寸、触控区、语义标签。

---

## AV06 · 图表与专项页颜色复核

**目标**：换色后所有图形仍可读，参照与当前点不混淆。

**改动**
- 复核并只在必要时调整：`components/charts.dart`、`category_bars.dart`、`battery_arc.dart`、`share_ring.dart`、`composition_bar.dart`、`soc_interval.dart`、`statistics_*.dart` 的绘制色。
- 确认系列次色（`accent` 50%）在浅色白卡与深色 surface 上都能区分主色。

**验收**
- 主系列、次系列、参照、当前点在浅/深两模式下的图形对比度 ≥3:1（对各自底色）。
- hero 内图表（统计里程走势、充电费用带）用 `accentHero` + `heroText` 12% 网格，可读。
- 参照虚线仍是 `[4,4]` `reference`，不被误读为数据系列。
- 图表空/缺失/进行中状态不变。

**不做**：不改图表几何、不新增图表类型、不改点读交互。

---

## AV07 · 正式渲染与图册

**目标**：用正式 Flutter 页面产出浅/深对照图，供"消费级"判断。

**改动**
- 新增 `docs/implementation/appearance-v2-renders/`（四主 Tab + 两类详情 × 浅/深 × 100/200% × normal，至少 1 张/页/模式）。
- 产出"旧 vs 新"并排对照（复用 `docs/implementation/a-renders/` 同机位）。
- README 索引：渲染命令、fixture、未覆盖项。

**验收**
- 每张图无横向溢出、无裁切；hero 卡片圆角与外距在地图上量得 20/12。
- 浅色图里不再出现暖米底 `#F1F0EB`、土黄参照、墨绿强调色。
- 图册与 Spec §13 验收清单逐条对应。

**不做**：不把渲染图当作真机/真实站点证据。

---

## AV08 · 文档与验收同步

**目标**：仓库内不存在与新决策矛盾的表述。

**改动**
- `docs/specs/visual-system-a.md`：§2.4 对比度表、§4 hero 形态、§9.8 外观设置默认值、§14 第 1 条；文首加"2026-11-02 由外观 v2 修订"指引。
- `docs/specs/mobile-v1.md`：追加 2026-11-02 增量段（默认跟随系统、电光蓝、浅色卡片 hero），指向本 Ticket 与 Spec。
- `docs/adr/0003-visual-direction-a.md`：在文首注明配色与默认外观已被 ADR 0006 修订。
- `AGENTS.md` / `README.md`：如出现"深色默认""玉绿"表述则更新。

**验收**
- 全仓 `grep` 不到"默认深色"作为现行规定的表述（历史记录段除外）。
- 每份文档的状态行与日期正确。

**不做**：不改写历史评审文档（direction-review-v2 等）的结论段。

---

## AV09 · 双轴审查与合入

**目标**：用 `code-review` 沿"标准"与"规格"两轴复核，修完再合。

**改动**
- 调用 `code-review`（起点为 AV01 之前的 commit），两轴并行审查。
- 修复明确问题；不明确项记录为待确认，不擅自扩大范围。

**验收**
- 两轴明确问题 0 未解决；审查结论归档到 `docs/implementation/appearance-v2-review.md`。
- 本地提交在 `main`（不推送、不改写共享历史）。

**不做**：不推送、不部署、不关闭外部待验票（#4/#11 等）。

---

## 风险登记

| 风险 | 影响 | 处置 |
| --- | --- | --- |
| 深色观感从"绿黑"变"冷黑"，超出用户对"换主题色"的预期 | 需要二次确认 | AV07 产出后先看深色对照图，必要时只回调 hero 光晕强度与 canvas 微差 |
| 卡片 hero 改变概览首屏构图 | 结构性回归 | AV02/AV03 单独成票、单独渲染验证；可独立回滚 |
| 浅色成为多数用户首屏，打磨不足即被放大 | 品质判定 | AV07 逐页对照，浅色优先级高于深色 |
| `accentSoft` 底 + `accent` 描边只有 2.93:1 | AA 边界 | 已在 Spec §7.1 定为选中 chip 用 `accentStrong` |
| 内容宽在卡片形态下缩 16–18px | 长数字/单位换行 | AV02 验收含 320 宽与 200% 实测 |
