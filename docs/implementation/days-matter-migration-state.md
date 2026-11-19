# DM04 状态诚实组件（MG09）实施记录

日期：2026-11-19。分支 `main`（工作区含其他并行在途改动，本次未提交、未推送）。
条款依据：`docs/specs/days-matter-migration.md` MG09（状态诚实三要素）、
`docs/specs/apple-polish.md` R31（状态与反馈矩阵）、
`docs/specs/apple-polish-copy.md` CP07（状态与错误文案构造）。

## 1. 改动文件

| 文件 | 变化 |
| --- | --- |
| `lib/src/design/components/state_view.dart` | StateView 与 InlineBanner 增量；详见 §2、§3 |
| `lib/src/copy/state_feedback.dart` | 新增：空态四档共享构造 + 「数据截至 HH:mm」时间句（§4） |
| `test/support/copy_guard_baseline/state_feedback.dart.txt` | 新增：新 copy 库文件基线，登记为 7 |
| `test/days_migration_state_test.dart` | 新增：三要素渲染与语义、文案快照、色彩映射、减动效（§5） |
| `docs/implementation/days-matter-migration-state.md` | 本记录 |

未改：`tokens.dart`、`semantic.dart`、`components.dart`、`module.dart`（InlineBanner 实际位于
`state_view.dart`，无需改 `module.dart`）、任何页面文件。全部新增参数可选、默认 null，
既有调用方零变化。

## 2. StateView 三要素（MG09）

- 整页态：保持现有「图形 48 + title2 + subheadline + 主按钮」；新增可选
  `statusLine`（时间或原因行，`footnote` 档，如「数据截至 14:02」），位置在
  说明与主按钮之间，间距 s4。
- compact 态：新增可选 `statusLine`（同上，footnote 档）与可选文字动作槽
  `textActionLabel` / `onTextAction` / `textActionSemanticLabel`：前景
  `accentStrong`（文字层强调色），`minimumSize` 44×44（`MileafSpace.touch`）。
- 读屏：时间行按渲染顺序位于说明之后、动作之前；文字动作槽沿用 D-AP08-03
  的 `Semantics(label: …, button: true)` 对象名机制。
- 既有动作参数（`actionLabel`/`onAction`）渲染与语义完全不变。

## 3. InlineBanner 三要素

- 三要素：现状句 = 既有 `message`（正文）；新增可选 `statusLine`
  （footnote、`textMuted`，位于正文之下，同一 live region 内，朗读顺序
  正文 → 时间行）；可选动作槽沿既有 `actionLabel`/`onAction` 不变。
- 色彩收口：`BannerTone` 由三档 `info/warning/error` 收为受限四档
  `neutral/warning/error/accent`，缺省 `neutral`；四档与 DM01 的
  `MileafStatusTone` 一一对应，取色统一转发到 DM01 的
  `MileafStatusToneColorResolver.resolveColor`（MG02 全站唯一映射表：
  neutral → `textSecondary`、warning → `warning`、error → `error`、
  accent → `accentStrong`）。页面不再能传任意颜色。
- **调用点迁移清单（取舍说明）**：任务前提「现有自由 Color 参数」与代码事实不符——
  InlineBanner 本就使用三值枚举而非自由 Color。枚举改名取最小迁移：
  `info` → `neutral` 的映射完全相同（`textSecondary`），且全库**没有任何调用点
  显式引用 `BannerTone.info`**（默认值在组件内），因此零调用点改动、视觉输出不变。
  `warning` / `error` 名称保留；新增 `accent` 档供 DM05–DM07 接线。
  若后续需要页面显式写 neutral，由 DM05–DM07 页面包自行替换。
- 减动效：出现/消失仍为高度 200ms + 透明度 160ms（M11/M08 既有裁定，不在本包范围）。

## 4. 空态分档文案（CP07 语气）

新文件 `lib/src/copy/state_feedback.dart`：`EmptyStateTier`（offline / loadFailed /
noData / filterNoMatch）× `emptyStateCopy(tier, {object})` → `EmptyStateCopy(status, action)`；
`dataAsOfLine(time)` → 「数据截至 HH:mm」（DF4 `formatTime`）。

| 档位 | 现状句 | 建议动作 |
| --- | --- | --- |
| 离线 | 网络不可用，显示的是缓存数据 | 重试 |
| 加载失败 | 没能读取{对象}（复用 CP07 `readFailedMessage`） | 重试 |
| 无数据 | 这段时间没有{对象}（复用 CP07 `emptyMessage`） | 刷新 |
| 筛选无结果 | 筛选后没有{对象} | 调整筛选 |

对象名缺省为「数据」。同一概念一个词：加载失败与无数据复用 `messages.dart`
既有构造，不在新文件重复字面量；未动 CP12 冻结文案；新文案先说发生了什么、
再说可以做什么。

## 5. copy guard 登记变化

- 机制：`test/apple_polish_copy_guard_test.dart` 按 `test/support/copy_guard_baseline/`
  每源文件一行计数基线（含中文单引号字面量的行数，注释豁免），只许下降；
  `lib/src/copy/` 新库文件另受 CP09 1–4 与精确旧串内容检查。
- 登记：新增 `state_feedback.dart.txt` = **7**（`数据`、`网络不可用…`、`重试`、
  `重试`、`刷新`、`筛选后没有…/调整筛选`、`数据截至 …` 七行）。基线计数对本文件通过。
- 已知非本包缺口：DM02 在途新文件 `lib/src/design/components/icons.dart`
  （25 行）尚未登记基线，文案守卫基线用例当前因此失败；该登记属 DM02 持有票，
  本包未代登。

## 6. 测试结果

- `test/days_migration_state_test.dart`：12 用例全过 ——
  整页态时间行位置与朗读顺序（几何自上而下）、不传参数零变化、compact 文字动作槽
  （accentStrong + 44 命中 + 可点）、compact 时间行 footnote 档、InlineBanner
  正文+时间行+动作与深度优先朗读顺序、neutral 不产生彩色、四档色彩映射（转发
  DM01 解析器）、`BannerTone`↔`MileafStatusTone` 逐档一致守卫、
  四档文案快照（字符串断言，非 golden）、时间句格式、减动效下 StateView 无
  AnimationController（StatelessWidget + transientCallbackCount == 0）。
- `test/design_components_test.dart`：63 用例全过（含既有 StateView/InlineBanner
  行为回归）。
- 受 InlineBanner 影响的既有测试：`apple_polish_ap08_test`、`apple_polish_ap14_test`、
  `apple_polish_copy_test`、`charging_expansion_test`、`overview_briefing_test`、
  `overview_visualization_test` 全过（合计 122 过 / 1 跳过）；`design_gallery_render_test`
  与 `apple_polish_ap04_render_test` 为 opt-in 渲染入口，默认跳过（与 AP07 同机制）。
- 残余失败（均非本包范围）：
  1. `apple_polish_ap04_test`「单位随 R22」：metric.dart 有并行在途改动
     （字号 17→15），断言期望 17.0 实际 15.0，与本次 diff 无交集。
  2. `apple_polish_copy_guard_test` 基线计数：DM02 在途 `icons.dart` 缺基线（见 §5）。
- 本包文件 `flutter analyze`：0 诊断（全库 analyze 的其余诊断同样来自
  DM02 在途 `icons.dart` 与 `creator/` 工作区，均非本包文件）。

## 7. 与 DM01 的对齐状态

实施启动时 `semantic.dart` 尚无 `MileafStatusTone`，组件先以局部受限枚举收口；
实施过程中 DM01 落地了 `MileafStatusTone { neutral, accent, warning, error }` 与
`resolveColor` 解析器（其文档明确「DM04 的 StateView / InlineBanner 参数枚举以此为准」），
本包随即对齐：

- `InlineBanner` 取色不再持有本地映射，`BannerTone.statusTone` 转发到
  `MileafStatusTone` 后统一走 `resolveColor`；accent 档随 MG02 唯一映射表解析为
  `accentStrong`（无既有调用点使用 accent 档，视觉零变化）。
- `BannerTone` 保留为转发别名（仅文档标注 Deprecated，不加 `@Deprecated` 注解——
  否则约 30 处既有页面调用点会产生 analyze 诊断）：DM05–DM07 接线时把参数与
  调用点直接改用 `MileafStatusTone`，随后删除本枚举。
- 新增守卫用例：`BannerTone` 四档转发与 `MileafStatusTone` 解析结果逐档一致，
  neutral 不产生彩色（MG02 口径）。
- StateView 未引入色彩参数（沿 kind 推导），无需对齐。

## 8. 边界遵守

- 未 git 提交、未推送。
- 未改 tokens.dart、semantic.dart、components.dart、module.dart、页面文件、
  CP12 冻结文案；`test/design_components_test.dart` 等他人持有文件只运行未改。
- 全部 flutter 命令经共享锁（/tmp/mileaf-flutter-lock）串行执行。
