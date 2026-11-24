# 统计·能耗专题（P08）版式修复（2026-11-19）

触发：用户以三张截图红框指出「统计 → 查看对比明细（该入口经 `selectTopic('energy')` 进入能耗专题）」整页显示错乱——① 结论卡与主图卡之间没有间距（元素堆叠）；② 点图上每个温度组的读数叠在一起；③ 温度组分段轨道折成一个团块；④「查看这些行程」与同页卡片不对齐；⑤「短途、中途与长途」的行内文字被压成一字一行。要求按规范修复。

一句话结论：五处是**同一类缺陷的不同侧面**——本页是全仓唯一把服务端浮点**原样上屏**的页面（`conditionsValue = num.toString()`），读数把行宽吃光；再加三处间距/插槽漏项（相邻卡缺 `cardInset`、页尾说明缺 `section`、下钻行二次内缩且没有行尾箭头）与两处未按规范降级（自绘读数标签只有 clamp、多行轨道仍画胶囊）。逐项按条款改回；补密集组数夹具后又发现并修掉一个既有的轴标签越界异常。

## 1 复现与证据

- 夹具：`test/support/raw_conditions_fixture.dart`（共享夹具，渲染入口与回归测试同取）
  - `rawConditions()`：在 `conditionsFixture()` 上加入**高精度合成浮点**和三组温区标签（5至10°C / 10至15°C / 15至20°C）。
  - `denseConditions()`：13 个温度组，复现线上真实的密集形态（`docs/implementation/ui-ux-refinement/U09b.md:85` 登记的「>6 组 × 大字」组合）。
  - 四舍五入过的夹具会让上述问题在渲染与断言里同时消失，所以夹具本身是证据的一部分。
- 渲染入口（opt-in）：`test/statistics_conditions_raw_render_test.dart`
  ```sh
  ./tool/flutterw test --no-pub test/statistics_conditions_raw_render_test.dart \
    --dart-define=MILEAF_RENDER_OUTPUT=build/conditions-fix-renders \
    '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
  ```
  产物：`build/conditions-fix-renders/`（430×932 / 390×844 / 360×800 / 390 深色 / 390 200% / 390 13 组 / 390 200% 13 组，各 top + 逐屏滚动）。`build/` 是生成物，不入库；代表样张见 [statistics-conditions-renders/](statistics-conditions-renders/README.md)。
- 修复前形态：用户 2026-11-19 三张截图（红框三处）；本节各项在 HEAD `b1d86ba` 上均可复现（见 §2 的「修复前代码事实」）。

### 舍入算例（原始浮点 → 上屏，Spec mobile-v1 §11 + CP03）

| 字段 | 夹具输入 | 上屏 |
| --- | --- | --- |
| 净电耗（结论卡 / 点图 / 距离行） | `164.38290651723641` | `164 Wh/km` |
| 净电耗（第二组） | `155.70834162957324` | `156 Wh/km` |
| 已知里程 / 距离 | `342.683510792146` | `342.7 km` |
| 单程中位数 | `62.87154029418361` | `62.9 km` |
| 配对能量 | `48.63150729` | `48.63 kWh` |
| 平均速度 | `47.26830451962731` | `47 km/h` |
| 配对里程 | `87.2385073` | `87.2 km` |

## 2 逐项处置

| # | 现象 | 条款 | 修复前（代码事实） | 修复 | 守卫 |
| --- | --- | --- | --- | --- | --- |
| 1 | 结论卡与主图卡贴合，两处圆角相切成「沙漏」缺口 | R24「同一区块内卡片之间 12」、CL20（卡间 12 = `cardInset`）；同级先例 P10 续航、P11 停放 | `build` 里 `_selectedGroup(b)` 与 `_plotSection(bins)` 直接相邻，间距 0 | `_plotSection` 外层补 `Padding(top: MileafSpace.cardInset)` | `同级相邻卡之间保持 cardInset 间距` |
| 2 | 原始浮点上屏：大号读数溢出、距离行标题被压成一字一行 | mobile-v1 §11（距离 1 位、速度/电耗整数、能量 ≤2 位）+ CP03（千分位、真负号）+ R02/R03（不靠缩字塞入） | `conditionsValue` = `num.toString()`，全页唯一裸值出口 | 字段级 formatter：`conditionsWhKm`/`conditionsSpeed`（整数）、`conditionsKm`（1 位）、`conditionsKwh`（`decimal`）、`conditionsCount`（整数），全部走 `number_format.grouped/decimal + applyMinusSign`；读屏同源；组边界 `_boundary` 保留 1 位小数（见 #7） | `服务端浮点按业务精度上屏，不出现原始长小数` |
| 3 | 点图读数标签互相叠压、越出绘图区 | R03「图轴可减少 tick，不能裁字」+ R06.4（轴布局、自绘文字）；U09b 已登记未决项 | 值标签只有 `clamp`，没有重叠/超宽消解 | 新增 `conditionsValueLabelOffsets`：锚点（选中组）优先，其余按与锚点的距离依次尝试；比绘图区还宽或与已放标签重叠的读数不画 | `点图读数标签互不重叠、不越出绘图区（选中组优先）`（纯函数精确断言 + 13 组 × 200% 真实绘制逐屏） |
| 4 | 温度组分段轨道折行后成一团块（用户截图 2 红框） | R24/CL21 形状语言「内容容器 lg / 控件胶囊」；R27 允许折行（每行至多 3 项） | `ChipRow` 只画一条 `borderRadius: full` 的轨道，高度覆盖全部行——两行之间的空隙被同一颗大胶囊填满 | 轨道半径按行数分档：单行仍是胶囊（`full`），折行后退回内容容器 `MileafRadius.lg` | `温度组分段轨道折行时不再是拉长的胶囊团块`（页面级）+ `折行后轨道退回内容容器半径`（`apple_polish_ap03_test` 组件级，单行胶囊断言保留） |
| 5 | 「查看这些行程」比同页其他卡多缩进一档、行尾没有箭头、与上方卡多空了一档 | R24「卡片外边 = 页面边距、卡内 16 由 `MileafGroupRow` 自带」、R01「父子不重复增加同一段间距」、CP06（「查看」开头 + 行尾箭头）、CL14（下钻行必须配图标） | `_evidenceRow` 外层再套一次 `MileafLayout.pageInset`（页面滚动视图已按 `pagePadding` 缩进）、没给 `trailing`、且用 `section` 而不是卡间 `cardInset`（它没有自己的区块标题） | 去掉二次内缩、卡间改 `cardInset`、补 `trailing: MileafIcon(chevron, inline, textFaint)`，与 `statistics_insights_page` 的下钻行同构 | `「查看这些行程」与同页卡片同宽对齐，行尾有箭头`（横向 + 纵向 + 箭头三断言） |
| 6 | 页尾「关于这些数据」标题贴着上一张卡 | R24「区块与区块 32」；`MileafDataNotes` 不自带上边距（同页 `_factsSection`/`_distanceSection` 都自带 `section`） | `_dataNotes` 直接返回 `MileafDataNotes` | 外层补 `Padding(top: MileafSpace.section)`，与 `statistics_range_page._notes` 同一写法 | 同一间距用例内追加「关于这些数据」断言 |
| 7 | 组边界被压成整数：分档步长改成 2.5 时 `[7.5, 10)` 会写成「8至10°C」 | mobile-v1 §11「温度 1 位小数、距离 1 位小数」+ 页尾自述「只显示真实分组值」 | `_signed` 走整数格式化 | `_boundary`：整数端点不补 `.0`，非整数保留 1 位 | `组边界保留小数：分档步长变成 2.5 时仍读得出真实区间` |
| 8 | **新用例发现的既有缺陷**：窄屏大字 + 多组时画布 `clamp` 抛 `ArgumentError`（`size.width - p.width < leftPad`） | R03「图轴可减少 tick，不能裁字」 | 轴标签 `(center - p.width/2).clamp(leftPad, size.width - p.width)`：标签比绘图区宽时下界大于上界 | 先判「标签比绘图区还宽就整条跳过」，再 clamp | 13 组 × 320 宽 × 200% 逐屏滚动不溢出 |

### 读数减量的实测（密集组数）

| 机位 | 组数 | 点图放行的读数 | 分段控件形态 |
| --- | --- | --- | --- |
| 390×844，100% | 13 | 7 个（首组必在） | 2 列 × 7 行，轨道 `lg` |
| 390×844，200% | 13 | 3 个（约为每 4 组一个） | 同上（行高随字号增长） |
| 390×844，100% | 3 | 3 个（全部） | 单行胶囊 |

## 3 组件层改动的授权边界

- `chip_row.dart` 是共享组件。改动只涉及**折行（rows > 1）**分支的轨道半径；单行分支的半径、轨道高 40、选中底 36、命中区、折行规则全部不变（`apple_polish_ap03_test` 原有断言未改）。
- **规格现状**：R24/CL21 只定义「控件 = 胶囊」「内容容器 = `MileafRadius.lg`」，R27 只规定折行数与每行至多 3 项；**多行轨道该长什么样，规范没有条文**。本次按上面的形状语言推导：折行后轨道已是在包住多行分段的容器，不再是「一个控件」，因此退回 `lg`。**没有新增 token、没有新增半径档**。这是推导而非新增条款，若要单独立条应回到 `docs/specs/apple-polish.md` R27 增补。
- 影响面（所有会折行的 `ChipRow` 调用点）：概览指标组（320 宽或大字 2×2）、概览与各详情的期间行（4 项 2+2）、补能专题分段、能耗专题温度组（本次目标）。其中能耗专题是唯一会折到 3 行以上的调用点；``apple_polish_ap03_test`` 的单行胶囊断言（轨道高 40 / 选中底 36 / `full`）与期间行几何断言均未改动，复跑全绿。
- 未做：不给 `ChipRow` 加「轨道形状」参数。理由是形状应由组件按行数决定（参数化会让每个调用点各自挑形状，与 CL21「页面不得自选半径」相反）。

## 4 范围外（本次不改，供裁定）

1. **P09 补能**的「结论卡 → 主图卡」用 `section`（32），而同构的 P10 续航、P11 停放与本次 P08 用 `cardInset`（12）。属既有跨页偏差，改动会牵动补能首屏预算，另行处理。
2. **P07 节奏**同样有两处 0 间距（结论卡 → 「每日里程」区块标题；距离卡 → 「关于这些数据」）。同类缺陷但不在用户反馈范围内。
3. **真实 8–13 组的信息架构**：本次只修形状与读数消解，分段控件在 13 组时仍是 2 列 × 7 行的「大盘」，点图放行 7/13 或 3/13 个读数。是否改用步进 + 下拉、或横向滚动，需产品裁定（U09b 已登记为未决项）；本次给出了上述实测数字，便于裁定。
4. **结论卡是否补域 tint**：`MileafModuleCard` 未传 `hue`（卡背是 `surface`），读数取色已按 CL55 改为 `solid`（本次修复，见 §2）。是否再补 tint 属外观取舍，留给视觉负责人。
5. **Wh/km 精度跨页分叉**：`statistics_insights_page._whKm` 在 API 值带小数时保留 1 位（`210.5` → `210.5`），本页按 §11 取整（`210.5` → `211`）。本页符合 §11，跨页统一另案。
6. **读屏措辞「净电耗」**：CP02 词表为「电耗 / 电耗（估算）」，但「净电耗」在统计根页与行程页作为字段名长期使用；本次只改这些句子的数字格式，未动措辞。
7. **CL14 只补了一半**：下钻行现有行尾动作图标（chevron）。CL14 ② 还要求「图标在左、间距 s8」，而 `MileafActionIcon` 没有「行程/列表」字形（候选最近的是 `compare`，语义不符），加错图标比不加更糟——登记为待补字形，不写进「已满足」。

## 5 双轴审查

**Standards**

- `./tool/flutterw analyze --no-pub lib test`：仅 1 条既有 info（`test/apple_polish_ap10_test.dart:342`），无新增。
- `./tool/flutterw dart format`：改动文件格式化后无变更。
- 裸值守卫（AP01 基线）不升高：新增格式化都走 `number_format`，没有新增 `fontSize`/`radiusCircular` 等字面量。
- 文案守卫（`apple_polish_copy_guard_test`）：可见文案未新增（`关于这些数据`/`查看这些行程` 等既有句子未改），只改数字格式。过程中新增的一条中文 `assert` 文案被守卫抓到（本文件 52 行 > 基线 51），按「基线只许下降」改成不带文案的 assert，未上调基线。
- 夹具落位：按 `docs/implementation/render-archive.md:44-47` 把本次新增的高精度夹具放进 `test/support/raw_conditions_fixture.dart`，供回归和渲染共用。基础响应和页面导航仍复用既有测试辅助函数。
- 测试：新增 10 例（`test/statistics_conditions_layout_test.dart` 9 例 + `apple_polish_ap03_test` 1 例），另有 1 个 opt-in 渲染入口（默认跳过）。

**Spec**

- R24/CL20 间距：卡间 12（新补 2 处）、区块 32（新补 1 处）、卡内 16（不变）、标题 → 卡 8（组件内，不变）。
- CP03 / mobile-v1 §11：电耗与速度整数、距离 1 位、能量 2 位、组边界保留小数、千分位、真负号；缺失仍是「—」，0 仍是 0（`0 Wh/km` 既有用例未改）。
- R03/R06.4：读数与轴标签都不再叠压或越界；不靠缩字、不裁字（放不下就不画，完整值由结论卡与读屏承担）。
- CP06/CL14：下钻行以「查看」开头、行尾箭头、与同页卡片同宽同线；行首动作图标在第二轮补上（见 §8）。
- 读数取色：第一轮按 CL55 把结论卡 metricLg 由 `strong` 改 `solid`；第二轮补了 CL02 的焦点卡 tint 后，按 CL51「洗色面上的一切彩色前景取 strong」又改回 `strong`（最终形态见 §8.1）。CL55 的分档仍作用于直接压在 surface 上的读数（样本明细的 `MetricBlock`）。
- R01：父子不重复加间距（下钻行的二次内缩被去掉）。
- 未触碰：结论卡/主图卡的内容顺序（R25 专题骨架）、点图步进与命中映射、`MileafGroupRow` 行高 52/64、分段折行规则（R27）、图表左留白算法（R06.4）。

## 6 验证

```sh
./tool/flutterw analyze --no-pub lib test
./tool/flutterw test --no-pub test/statistics_conditions_layout_test.dart
./tool/flutterw test --no-pub test/statistics_conditions_test.dart test/ui_ux_u09b_test.dart test/apple_polish_ap03_test.dart
./tool/flutterw test --no-pub            # 全量
```

结果（两轮合并）：`analyze` 仅 1 条既有 info（`test/apple_polish_ap10_test.dart:342`）；`statistics_conditions_layout_test` 11 例 + `apple_polish_ap03_test` 1 例组件轨道全绿；全量 **1361 通过 / 57 跳过 / 0 失败**（HEAD 基线 1347/56，本切片 +12 例、另有 1 例 opt-in 渲染入口默认跳过；余下增量来自同一工作区的并行会话）。样张见 [statistics-conditions-renders/](statistics-conditions-renders/README.md)。

## 7 未提交

按 `AGENTS.md`「不擅自提交、推送」：改动留在工作区，提交需当次授权。涉及文件：

- 生产代码：`lib/src/statistics_conditions_page.dart`、`lib/src/design/components/chip_row.dart`（第一轮）、`lib/src/statistics_usage_page.dart`、`lib/src/statistics_charging_page.dart`、`lib/src/statistics_insights_page.dart`（第二轮裁定项，见 §8）。
- 测试：`test/statistics_conditions_layout_test.dart`、`test/statistics_conditions_raw_render_test.dart`、`test/support/raw_conditions_fixture.dart`、`test/apple_polish_ap03_test.dart`、`test/ui_ux_u09b_test.dart`、`test/statistics_insights_test.dart`、`test/ui_ux_u08_test.dart`。
- 文档：本文、`docs/implementation/statistics-conditions-renders/`、`docs/implementation/README.md`、`docs/agents/history.md`。

同轮工作区另有并行会话的在途切片（概览读数头第三行），本记录只覆盖统计专题这一支。

## 8 第二轮：用户裁定「全部按照推荐实施」（2026-11-19 20:10）

第一轮结尾列出的七项待裁定项，用户裁定**全部按推荐落地**。逐项如下：

| # | 项 | 条款 | 落地 | 守卫 |
| --- | --- | --- | --- | --- |
| 8.1 | 结论卡补焦点卡背板 | CL02/CL06（焦点卡叠 tint）+ CL51（洗色面前景取 strong）；与 P09 补能、P10 续航的焦点卡同构 | `MileafModuleCard(hue: efficiency)` + 读数回 `strong`（第二轮修正第一轮只取 `solid` 的形态） | `结论卡是焦点卡：efficiency 洗色底 + strong 读数 + route 行首图标` |
| 8.2 | CL14 行首动作图标（第一轮登记「缺字形」） | CL14/CL12：下钻行必须带图标，行首图标取所属数据域 | 既有 `MileafIconName.route` 正好是「行程＝路线」，`leading: route` + `hue: journey` | 同上 |
| 8.3 | CP02 词表收敛 | CP02：短标签「电耗」、完整名「电耗（估算）」；「净电耗」是字段名 | 结论卡读屏、「暂无净电耗」、点图逐组读屏三处去「净」 | `ui_ux_u09b_test`（读屏句与空值句） |
| 8.4 | 真实 8–13 组的分段信息架构 | R03「互斥控件不足时改两行/纵向选项，不做挤压省略」+ R27「每行至多 3 项」+ R09「大字下不产生三行胶囊残片」 | 组数 > `conditionsSegmentLimit`（6）时，分段轨道换成 `MileafPullDown`：胶囊只显示当前组，完整清单在浮层里纵向排列；≤6 组仍是胶囊分段 | `组数超过 6 时分段改下拉（R03 纵向选项），选择仍能切组`（13 组夹具，点选后结论卡读数跟着变） |
| 8.5 | P09 补能卡间 32 → 12 | R24「同一区块内相邻卡片之间 12」；与 P10/P08 同构 | 结论卡 → 趋势图的 `top:` 由 `section` 改 `cardInset` | 既有补能专题用例 + 渲染复核 |
| 8.6 | P07 节奏补齐页面节奏 | R24 间距总表 | 结论卡 → 「每日里程」等 4 个带区块标题的节各补 32；页尾说明补 32 | 既有节奏专题用例 + 渲染复核 |
| 8.7 | 电耗精度跨页统一 | Spec mobile-v1 §11「速度/电耗整数」 | `statistics_insights_page._whKm` 由「带小数时保留 1 位」改为取整；统计根页 `187.5 Wh/km` → `188 Wh/km` | `statistics_insights_test`（3 处）、`ui_ux_u08_test`（2 处）同步 |

**顺带记两条边界**

- 8.4 的阈值 6 = R27 的「每行至多 3 项」× 2 行。选 7 组以上的理由：三行起就是 R09 明令避免的「三行胶囊残片」，而 R03 允许把互斥控件改成纵向选项——下拉的浮层正是纵向列表。
- 8.4 的下拉**没有**给 `label`：文案守卫基线只许下降，「温度组」这个新增读屏名目会被守卫判为新增文案；胶囊本身读的是当前组值，上方「按行程平均气温分组，每组 5°C」已经交代对象。若后续允许上调基线，再补这一句。

**第二轮后的复核**：`analyze` 无新增（仍只有 `test/apple_polish_ap10_test.dart:342` 一条既有 info）、`dart format` 无变更；全量 **1361 通过 / 57 跳过 / 0 失败**（第一轮 1359 + 本轮新增 2 例）。样张已按新形态重渲（结论卡洗色底、13 组下拉、下钻行 route 图标）。


## 9 主线交付复核（2026-11-24）

- P08 浮层在温度组选项超过六个，或分段按实际宽度和字号计算后超过两行时启用。窄屏 200% 字号下用 5、6 和 13 组验证，普通宽度仍保留能放进两行的分段。
- 下拉触发器沿用平台触控高度，触发器与选项提供独立的读屏点击动作。当前选项进入菜单时获得键盘焦点，菜单文字可换行且行高按实际字号计算。
- 公开样张与测试夹具改用合成汇总值。更新 8 张定点 Flutter 样张，保留高精度读数、缺失值与密集温区形态。
