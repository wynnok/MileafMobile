# 充电记录行与地点行重排实施记录

2026-11-18 在 `main` 工作区完成（基线 `af126cc`）。条款依据：[apple-polish](../specs/apple-polish.md) R21 第 5 条（三列网格只用 `metricSm`、两列网格可用 `metricMd`）、R22（字体角色：记录行标题 `headline`、记录尾值 `metricSm`）、R23.1（功能文字只有 `text`/`textSecondary` 两级，`textFaint` 只留占位/禁用/装饰）、R24（「两条起始线」与卡片内边距 16、分隔线规则、间距档位）、R25；[焕新规格](../specs/ui-ux-refinement.md) R05（列表行合同：整行可点、局部费用动作独立不串跳）、R09（元信息不用「·」拼长句，改分行成列）、R10（测试断言放宽需映射规则）；文案合同见 [apple-polish-copy](../specs/apple-polish-copy.md) CP02/CP03/CP04/CP09/CP10。配色、字号、圆角、动效 token 一律沿用既有值，未新增。

## 1 问题

用户在充电页两处红框（「最近充电」记录卡与「充电地点」分组卡）。对照改前渲染（`charging-rows-renders/before/`）：

| 改动前 | 后果 |
| --- | --- |
| 记录行与地点行**直接贴卡片边缘**（`MileafGroupCard` 默认零内距，行未包横向内距） | 与同页三格账目卡（卡内 16）两条左缘，违反 R24「两条起始线」；分隔线却从 16 起，线比文字更靠里 |
| 结果行是 `Wrap`：「充入 **46.8** kWh」（metricSm）与「电网用电 22 kWh」「费用 ¥71.28」（footnote）挤一行 | 三种字号同排、WrapCrossAlignment.center 基线错落；换行点随内容漂移，阅读顺序不固定 |
| 地点行是 `MileafDataRow` 的三行等权 meta：「8 次，充入 160 kWh / 8 次中 2 次有费用 / 充入均价 0.4 ¥/kWh」 | 没有主值、数字不成列；三个数字（次数、电量、均价）埋在同样灰的小字里 |

## 2 设计

两组行共用同一套「标题行 → 元信息 → 读值网格」句法，读值网格与页内三格账目卡同构（标签在上、数值同基线成列）：

```
家 · 地库                                        ›
8 次中 2 次有费用
充入 160 kWh        充入均价 0.4 ¥/kWh
```

```
家 · 地库                                       [DC]
3月29日 07:10，34 分钟
[▓▓▓▓░░░░▓▓]   开始 18%        结束 82%
充入 46.8 kWh       电网用电 22 kWh
费用 ¥71.28
[补录费用]（仅缺费用时）
```

规则：

1. **两条起始线（R24）。** 记录卡与地点卡的行都经 `_cardRow` 包 `horizontal: cardPad`（与概览 `_rowCard` 同一手势），分隔线仍从卡内 16 到卡片右缘——文字与分隔线终于同一条左缘。
2. **读值网格取代流式 Wrap（R21 第 5 条）。** `MetricBlock` 标签（subheadline）在上、数值在下，`MetricGrid` 默认两列收列：充入 / 电网用电 / 费用固定顺序，第三格放不下时换行而不是把字号挤小；大字（≥130%）自动单列堆叠。记录行三格用 `metricSm`（三列规则）；地点行两格用 `metricMd`（两列可用档，与账目卡同档）——地点行的主值由此真正立起来。费用格带币种口径旁注：币种未记录时旁注落费用格（与概览「费用覆盖落费用格」同一手法），不再拼进金额行；USD 等后缀币种数值写作「12 USD」，读值语义合成为一句「费用 12 USD」。
3. **地点行改成结论式。** 覆盖句一行（CP02 句式「N 次中 M 次有费用」，总数已含在句内，不再重复「N 次，」）；「充入 / 充入均价」两格；充入电量缺失时数值为「—」+ 旁注「充入电量缺失」；币种未设置时均价不带「币种未记录/kWh」这样的单位，改为无单位 + 旁注。箭头只留在标题行尾；整行可点（`Semantics` 合成标签 + `InkWell`）。
4. **补录动作独立成行。** `ChargingCostAction` 从 Wrap 里拿出来，落在网格之后左对齐（间距 8），点按不触发行导航（S06/S07 沿旧）。
5. **网格标签回到功能文字两级（R23.1）。** `MetricBlock` 非聚焦标签由 `textFaint` 改 `textSecondary`（`heroFaint` 的聚焦卡路径不变）——本切片新增的四类字段名标签属于功能文字；这是共享组件的一行修正，概览/统计/详情的所有 `MetricBlock` 标签随之回到 R23.1 合规档（可见变化：标签变深一档）。

**大字与窄屏**：360 宽 100% 记录行第三格（费用）换行成两行网格；200% 全部单列堆叠，行自然增高，无横向溢出（见 `charging-rows-renders/` 的 360 与 200% 机位，含深色 200%）。地点标题行 100% 最多两行（焕新规格 R03），大字完整显示。

## 3 变更

| 文件 | 变更 |
| --- | --- |
| `lib/src/charging_page.dart` | `_recordRow`：结果区由 `Wrap` 改为 `MetricGrid` 三格（充入/电网用电/费用），费用格带币种旁注与合成语义标签，补录胶囊移到网格后独立一行；`_locationRow`：由 `MileafDataRow` 三行 meta 改为「标题行 + 覆盖句 + 两格读值网格（metricMd）」；新增 `_cardRow`（卡内行共享横向内边）与顶层 `chargingLocationKey()`（地点行稳定 key，页面与测试共用）；`_recordCard` 与地点分组卡的行经 `_cardRow` 包内边 |
| `lib/src/design/components/metric.dart` | `MetricBlock` 非聚焦标签颜色 `textFaint` → `textSecondary`（R23.1，见 §2 规则 5） |
| `test/charging_test.dart` | 记录行断言改为网格结构（标签与数值分立）；费用零/缺失/USD 断言改走 `bySemanticsLabel`；空统计用例分两步滚动（记录行增高后惰性视口不再同时构建相邻两卡） |
| `test/charging_reading_test.dart` | 「费用 —，币种未记录」等整行文本断言改 `bySemanticsLabel`；地点行查找改为 `chargingLocationKey` |
| `test/charging_expansion_test.dart` | 地点行查找改 `chargingLocationKey`（5 处） |
| `test/charging_method_section_test.dart` | 三列「20 kWh」计数断言收进方式卡内（记录行读值网格可能出现同值文本） |
| `test/collage_charging_test.dart` | 覆盖句断言移到页顶（记录行增高后账目卡与趋势卡不再同留惰性视口） |
| `test/overview_statistics_reading_test.dart` | 子路由补录的胶囊查找去掉 `hitTestable` 预判并居中后点按（行增高后胶囊可能停在悬浮底栏之下） |
| `test/apple_polish_ap10_test.dart` | 全部记录模式下拉断言收进 `MileafPullDown` 内（记录行费用格语义同样以「费用」开头，原 `^费用` 断言不再唯一） |
| `test/support/copy_guard_baseline/charging_page.dart.txt` | 基线 114 → 119。R10 映射：本次不是放宽既有断言，而是新读值结构（标签/数值分立，R21 第 5 条网格语法）带来新的中文字面量行；护栏机制按「每源文件行数计数」运行，基线随结构登记上升，无旧文案被放行 |
| `test/charging_rows_render_test.dart` | 新增 opt-in 渲染入口（`skip: output.isEmpty || fontPath.isEmpty`，与 AP07 入口同一机制）：最近充电记录卡与充电地点卡，浅/深 390 100%、浅/深 200%、浅 360 |

数据、查询、动作与语义信息未变：行点击仍走 `onRecord('charge', id)` 与地点筛选，补录入口条件不变，地点行读屏顺序与原 `MileafDataRow` 合成标签一致（名称，覆盖句，充入，充入均价）。

## 4 动效

不新增动画。行内只有既有的按压覆盖层与 chip 状态；读值网格是静态内容，R07 白名单不涉及（AGENTS 2026-11-16 口径中的「微动效」按 R07 白名单执行：本区没有登记在册的动效事件）。

## 5 候选（未确认建议，不属本切片）

- 地点行「充入均价」格是否随格带 CP02 完整口径旁注（「按充入电池的电量计」）——现行同屏账目卡已带，地点行未带；旧行同样没有，为可缩不减义的现状。
- `MileafDataRow` 的 meta 与自定义结论式行今后是否统一（行程页记录行仍是 meta 串）；若统一，地点行句法是参照实现。
- `textFaint` 的调色板对比度问题（AGENTS 2026-11-16 登记）在 R23.1 本条修正后仅剩占位/禁用/装饰用途，调色板层是否调整仍待定。

## 6 验证

- `tool/flutterw analyze lib`：No issues found。
- `tool/flutterw test` 充电面（charging / charging_reading / charging_expansion / charging_cost / charging_cost_refresh / apple_polish_ap10 / apple_polish_copy_guard / full_flow / a_charging / statistics_charging）：全通过；全量套件结果见同日运行记录。
- 渲染图册：`charging-rows-renders/`（after）与 `charging-rows-renders/before/`（改前同机位），浅/深/200%/360 对照。
- 真机字体、读屏与性能仍属 #16/#17 外部 gate，本次不关闭。
